using System;
using System.Threading.Tasks;
using Newtonsoft.Json;
using Microsoft.Azure.Cosmos;

namespace CosmosDBTest
{
    public class User
    {
        // Cosmos requires the JSON property to be exactly "id"
        [JsonProperty(PropertyName = "id")]
        public string Id { get; set; } = Guid.NewGuid().ToString();

        // Partition key path is "/emailAddress"; ensure property name matches
        [JsonProperty(PropertyName = "emailAddress")]
        public string EmailAddress { get; set; } = string.Empty;

        [JsonProperty(PropertyName = "name")]
        public string Name { get; set; } = string.Empty;
    }

    public class Program
    {
        // Connection string for the Cosmos DB emulator
        private static readonly string EndpointUri = "http://localhost:7777";
        private static readonly string PrimaryKey = "C2y6yDjf5/R+ob0N8A7Cgv30VRDJIWEHLM+4QDU5DE2nQ9nDuVTqobD4b8mGGyPMbIZnqyMsEcaGQy67XIw/Jw==";
        private static readonly string DatabaseId = "MyDb";
        private static readonly string ContainerId = "Users";
        
        public static async Task Main(string[] args)
        {
            // Create a new Cosmos client with emulator connection
            // Disable SSL verification for local emulator
            CosmosClientOptions clientOptions = new CosmosClientOptions
            {
                HttpClientFactory = () =>
                {
                    HttpClientHandler httpClientHandler = new HttpClientHandler
                    {
                        ServerCertificateCustomValidationCallback = (_, _, _, _) => true
                    };
                    return new HttpClient(httpClientHandler);
                },
                ConnectionMode = ConnectionMode.Gateway,
                RequestTimeout = TimeSpan.FromSeconds(30)
            };

            CosmosClient cosmosClient = new CosmosClient(EndpointUri, PrimaryKey, clientOptions);
            
            try
            {
                Console.WriteLine("Beginning Cosmos DB emulator test...");
                
                // Wait for emulator to be ready with retries
                const int maxRetries = 10;
                int retryCount = 0;
                Exception? lastException = null;
                
                while (retryCount < maxRetries)
                {
                    try
                    {
                        Console.WriteLine($"Attempt {retryCount + 1} of {maxRetries}: Connecting to Cosmos DB emulator...");
                                  // Try to get the account properties as a connection test
                var accountProperties = await cosmosClient.ReadAccountAsync();
                Console.WriteLine($"Successfully connected to Cosmos DB emulator!");
                Console.WriteLine($"Account endpoint: {accountProperties.Id}");
                break;
                    }
                    catch (Exception ex)
                    {
                        lastException = ex;
                        retryCount++;
                        
                        if (retryCount < maxRetries)
                        {
                            Console.WriteLine($"Connection attempt {retryCount} failed: {ex.Message}");
                            Console.WriteLine($"Waiting 5 seconds before retry...");
                            await Task.Delay(5000);
                        }
                        else
                        {
                            Console.WriteLine($"All {maxRetries} connection attempts failed. Last error: {ex.Message}");
                            throw;
                        }
                    }
                }
                
                // Get references to our database and container
                Database database;
                Container container;
                
                try
                {
                    // Try to get the database
                    database = cosmosClient.GetDatabase(DatabaseId);
                    
                    // Check if database exists by trying to read it
                    var databaseResponse = await database.ReadAsync();
                    Console.WriteLine($"Database '{DatabaseId}' exists");
                }
                catch (CosmosException ex) when (ex.StatusCode == System.Net.HttpStatusCode.NotFound)
                {
                    // Database doesn't exist, create it
                    Console.WriteLine($"Database '{DatabaseId}' does not exist, creating it...");
                    var databaseResponse = await cosmosClient.CreateDatabaseAsync(DatabaseId);
                    database = databaseResponse.Database;
                    Console.WriteLine($"Database '{DatabaseId}' created");
                }
                
                try
                {
                    // Try to get the container
                    container = database.GetContainer(ContainerId);
                    
                    // Check if container exists by trying to read it
                    var containerResponse = await container.ReadContainerAsync();
                    Console.WriteLine($"Container '{ContainerId}' exists");
                }
                catch (CosmosException ex) when (ex.StatusCode == System.Net.HttpStatusCode.NotFound)
                {
                    // Container doesn't exist, create it
                    Console.WriteLine($"Container '{ContainerId}' does not exist, creating it...");
                    var containerResponse = await database.CreateContainerAsync(ContainerId, "/emailAddress");
                    container = containerResponse.Container;
                    Console.WriteLine($"Container '{ContainerId}' created");
                }
                
                // Create a new user
                User newUser = new User
                {
                    EmailAddress = "test@example.com",
                    Name = "Test User"
                };
                
                Console.WriteLine($"Inserting new user with ID: {newUser.Id}");
                
                // Insert the user into the container
                ItemResponse<User> createResponse = await container.CreateItemAsync(newUser, new PartitionKey(newUser.EmailAddress));
                Console.WriteLine($"Created item. Request charge: {createResponse.RequestCharge} RUs");
                
                // Query for the user
                QueryDefinition queryDefinition = new QueryDefinition("SELECT * FROM c WHERE c.emailAddress = @emailAddress")
                    .WithParameter("@emailAddress", "test@example.com");
                
                FeedIterator<User> queryResultSetIterator = container.GetItemQueryIterator<User>(queryDefinition);
                
                Console.WriteLine("Running query to find the inserted user:");
                while (queryResultSetIterator.HasMoreResults)
                {
                    FeedResponse<User> currentResultSet = await queryResultSetIterator.ReadNextAsync();
                    foreach (User user in currentResultSet)
                    {
                        Console.WriteLine($"\tFound user: {user.Id} - {user.Name} ({user.EmailAddress})");
                    }
                }
                
                Console.WriteLine("Cosmos DB emulator test completed successfully!");
            }
            catch (CosmosException cosmosException)
            {
                Console.WriteLine($"Cosmos DB operation failed. Status code: {cosmosException.StatusCode}, Error: {cosmosException.Message}");
                Console.WriteLine($"Activity ID: {cosmosException.ActivityId}");
                Console.WriteLine($"Request charge: {cosmosException.RequestCharge}");
                
                // Additional diagnostic information
                Console.WriteLine("=== Diagnostic Information ===");
                Console.WriteLine($"Endpoint: {EndpointUri}");
                Console.WriteLine($"Database ID: {DatabaseId}");
                Console.WriteLine($"Container ID: {ContainerId}");
                // Repro sentinel: detect the specific vNext issue (#199)
                if ((int)cosmosException.StatusCode == 500 &&
                    cosmosException.Message.Contains("schema \"cosmos_api\" does not exist", StringComparison.OrdinalIgnoreCase))
                {
                    Console.WriteLine("REPRO_SIGNAL: COSMOS_API_SCHEMA_MISSING");
                    // Distinct exit code for CI to pick up
                    Environment.Exit(42);
                }
                
                throw;
            }
            catch (HttpRequestException httpEx)
            {
                Console.WriteLine($"HTTP request failed: {httpEx.Message}");
                Console.WriteLine($"Data: {httpEx.Data}");
                
                // Additional diagnostic information
                Console.WriteLine("=== Diagnostic Information ===");
                Console.WriteLine($"Endpoint: {EndpointUri}");
                Console.WriteLine($"Database ID: {DatabaseId}");
                Console.WriteLine($"Container ID: {ContainerId}");
                
                // Check if it's a connection issue
                if (httpEx.Message.Contains("Connection refused"))
                {
                    Console.WriteLine("This appears to be a connection issue. Possible causes:");
                    Console.WriteLine("1. Cosmos DB emulator is not running");
                    Console.WriteLine("2. Port 7777 is not accessible");
                    Console.WriteLine("3. SSL certificate validation is failing");
                    Console.WriteLine("4. Network connectivity issue");
                }
                
                throw;
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error: {ex.Message}");
                Console.WriteLine($"Exception type: {ex.GetType().Name}");
                Console.WriteLine($"Stack trace: {ex.StackTrace}");
                
                // Additional diagnostic information
                Console.WriteLine("=== Diagnostic Information ===");
                Console.WriteLine($"Endpoint: {EndpointUri}");
                Console.WriteLine($"Database ID: {DatabaseId}");
                Console.WriteLine($"Container ID: {ContainerId}");
                
                throw;
            }
            finally
            {
                // Clean up the CosmosClient
                cosmosClient.Dispose();
            }
        }
    }
}
