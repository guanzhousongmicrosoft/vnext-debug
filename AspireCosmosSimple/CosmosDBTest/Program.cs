using System;
using System.Threading.Tasks;
using Microsoft.Azure.Cosmos;

namespace CosmosDBTest
{
    public class User
    {
        public string Id { get; set; } = Guid.NewGuid().ToString();
        public string EmailAddress { get; set; } = string.Empty;
        public string Name { get; set; } = string.Empty;
    }

    public class Program
    {
        // Connection string for the Cosmos DB emulator
        private static readonly string EndpointUri = "https://localhost:8081";
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
                ConnectionMode = ConnectionMode.Gateway
            };

            CosmosClient cosmosClient = new CosmosClient(EndpointUri, PrimaryKey, clientOptions);
            
            try
            {
                Console.WriteLine("Beginning Cosmos DB emulator test...");
                
                // Get references to our database and container
                Database database = cosmosClient.GetDatabase(DatabaseId);
                Container container = database.GetContainer(ContainerId);
                
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
                throw;
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error: {ex.Message}");
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
