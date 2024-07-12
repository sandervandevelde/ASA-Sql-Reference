using Microsoft.Azure.Devices.Client;
using Newtonsoft.Json;
using System.Text;

namespace AsaTestConsoleApp
{
    internal class Program
    {
        static void Main(string[] args)
        {
            Console.WriteLine("Hello, ASA World!");

            var connectionString = Environment.GetEnvironmentVariable("ASADEVICECLIENT");

            using var deviceClient = DeviceClient.CreateFromConnectionString(connectionString);

            SendMessage(deviceClient);
        }

        private static void SendMessage(DeviceClient deviceClient)
        {
            var messageBody = new MessageBody { deviceId = "sensor-001", temp = 78, pressure = 1003, time = DateTime.Now }; 

            string jsonData = JsonConvert.SerializeObject(messageBody);

            using var message = new Message(Encoding.UTF8.GetBytes(jsonData));

            deviceClient.SendEventAsync(message).Wait();

            Console.WriteLine($"A message is sent: '{jsonData}'");
        }
    }

    class MessageBody
    {
        public DateTime time { get; set; }

        public double temp { get; set; }

        public double pressure { get; set; }

        public string deviceId { get; set; }
    }
}
