# Create Azure resources

## Prerequisites

The names seen must be used for reference. Please use your own set of names.

Next to creating resources using Azure CLI commands, other commands are used to inspect created resources and secrets needed further down the line.

To install and use Azure CLI, check this [documentation](https://learn.microsoft.com/cli/azure/install-azure-cli?WT.mc_id=AZ-MVP-5002324)

## Create a resource group

### Create a resource group

```
az group create --name sql-reference-test-rg --location westeurope
```

## Create a storage account

### Create a storage account

```
az storage account create --name sqlreferenceteststor --resource-group sql-reference-test-rg -l westeurope --sku Standard_LRS --kind StorageV2
```

### Get the storage account connection string

```
az storage account show-connection-string --name sqlreferenceteststor --resource-group sql-reference-test-rg
```

*Note*: This storage account connectionstring is needed by the stream analytics job for storing reference data.

## Create an iothub

### Create an iothub

```
az iot hub create --name sql-reference-test-ih -g sql-reference-test-rg --location westeurope --sku S1 --partition-count 4
```

*Note*: The partition count is set to 4. Set it to 2 if you are using the free tier.

### Get the iot hub connection string 

```
az iot hub connection-string show --hub-name sql-reference-test-ih --key-type primary
```

*Note*: This iot hub connection string is needed by the stream analytics job iot hub input to connect.

### Create a 'asa' consumer group on the default output stream

```
az iot hub consumer-group create --hub-name sql-reference-test-ih --name asa
```

### Register a device

```
az iot hub device-identity create -n sql-reference-test-ih -d testdevice --ee
```

### Get the device connection string

```
az iot hub device-identity connection-string show --device-id testdevice --hub-name sql-reference-test-ih
```

*Note*: This device connection string is needed by the IoT Hub client to connect.

## Create SQL Server and SQL database (plus firewall rules) 

### Create SQL Server

```
az sql server create --name sql-reference-test-srvr --resource-group sql-reference-test-rg --location northeurope --admin-user adminsql --admin-password demosecret
```

*Note*: Provide your own name and password. The complexity of the password will be checked upfront. These are needed by the stream analytics job reference input to connect.

### Create sql server firewall for azure resources having access (needed for Stream Analytics)

```
az sql server firewall-rule create -g sql-reference-test-rg --server sql-reference-test-srvr -n azureaccess --start-ip-address 0.0.0.0 --end-ip-address 0.0.0.0
```

### Create sql server firewall for your own ip address having access (needed by you to add SQL statements)

```
az sql server firewall-rule create -g sql-reference-test-rg --server sql-reference-test-srvr -n myownipaddress --start-ip-address 88.111.55.88 --end-ip-address 88.111.55.88
```

If you want to know your local IP address, run this in a bash shell on your local machine:

```
ip=$(curl ipinfo.io/ip)
$ip
```

### Creating a SQL database within SQL server

```
az sql db create --resource-group sql-reference-test-rg --server sql-reference-test-srvr --name referencedb --edition GeneralPurpose --family Gen5 --capacity 2 --zone-redundant false --free-limit-exhaustion-behavior AutoPause --free-limit false
```

*Note*: Here, I try to create a paid database. Technically, a free database should work too. You can create maximum one free SQL database per subscription. Fill in 'true' at the end for a free database (if applicable).

### Create the table and load the sample records

In the Azure portal, navigate to the 'referencedb' resource.

navigate to the 'Query editor (preview)' tab in the 'referencedb' resource.

Login using the name and password seen above.

Check the file 'SQL script.sql' in the folder '02 sqlserver' for the first commands and inserts.

Execute only step 1/2:

- Create the table
- Add 7 rows
- Run the test query returning only 4 rows 
- Notice only clients A and D are interested in 'sensor-001' alerts 

## Create an eventhub namespace with eventhub

### Create an eventhub namespace

```
az eventhubs namespace create --name sql-reference-test-ehns --resource-group sql-reference-test-rg -l westeurope --sku Standard
```

This creates a 'Standard' tier eventhub namespace.

*Note*: you need to have a 'Standard' tier eventhub namespace when you need more than one consumer group per event hub. 

### get the RootManageSharedAccessKey of the eventhub namespace

```
az eventhubs namespace authorization-rule keys list --resource-group sql-reference-test-rg --namespace-name sql-reference-test-ehns --authorization-rule-name  RootManageSharedAccessKey
```

*Note*: This eventhub namespace key is needed by the stream analytics job eventhub output to connect.

### Create an eventhub 

```
az eventhubs eventhub create --name alerteh --resource-group sql-reference-test-rg --namespace-name sql-reference-test-ehns --partition-count 4
```

*Note*: The same amount of partitions is filled in as in the IoT Hub to prevent 'funneling'.

## Create a stream analytics job

```
az stream-analytics job create --job-name sql-reference-test-asa --resource-group sql-reference-test-rg --location westeurope --compatibility-level "1.2" --data-locale "en-US" --content-storage-policy JobStorageAccount --job-storage-account authentication-mode=connectionstring account-name=sqlreferenceteststor account-key=key== --transformation name="basictransformation" streaming-units=1 query="Select * into eventhuboutput from iothubinput" --output-error-policy "Drop" --out-of-order-policy "Adjust" --order-max-delay 5 --arrival-max-delay 16
```

*Note*: Fill in storage account connectionstring secrets.

*Note*: this will create a 'Standard' SKU, not the new 'StandardV2'

### Create an 'iothubinput' 

```
az stream-analytics input create --job-name sql-reference-test-asa --resource-group sql-reference-test-rg --input-name iothubinput --properties '{"type":"Stream","datasource":{"type":"Microsoft.Devices/IotHubs","properties":{"consumerGroupName":"asa","endpoint":"messages/events","iotHubNamespace":"sql-reference-test-ih","sharedAccessPolicyKey":"key=","sharedAccessPolicyName":"iothubowner"}},"serialization":{"type":"Json","encoding":"UTF8" } }'
```

*Note*: Fill in iot hub connectionstring secrets.

## Create a 'sqlreferenceinput'

```
az stream-analytics input create --job-name sql-reference-test-asa --resource-group sql-reference-test-rg --input-name sqlreferenceinput --properties '{ "type" : "Reference", "datasource": { "type": "Microsoft.Sql/Server/Database", "properties": { "authenticationMode": "ConnectionString", "database": "referencedb", "deltaSnapshotQuery": "", "fullSnapshotQuery": "SELECT DeviceId, ClientId, EmailAddress, IsEnabled FROM dbo.DeviceAlerts WHERE IsEnabled = 1", "password": "demosecret", "refreshRate": "0:01:00", "refreshType": "RefreshPeriodicallyWithFull", "server": "sql-reference-test-srvr", "user": "adminsql" } }, "serialization": { "type": "Json", "encoding": "UTF8" } }'
```

*Note*: Fill in sql server database secrets.

*Note*: This reference data is updated once a minute. This will create new storage account blobs every minutes. Check out the delta snapshot to overcome this.   

## Create a 'eventhuboutput'

```
az stream-analytics output create --job-name sql-reference-test-asa --resource-group sql-reference-test-rg --output-name eventhuboutput --datasource '{"type":"Microsoft.ServiceBus/EventHub", "properties": { "authenticationMode": "ConnectionString","eventHubName": "alerteh", "serviceBusNamespace": "sql-reference-test-ehns", "sharedAccessPolicyKey": "primarykey=", "sharedAccessPolicyName": "RootManageSharedAccessKey" } }' --serialization '{"type":"Json","properties":{"format":"LineSeparated","encoding":"UTF8"}}'
```

*Note*: Fill in event hub namespace secrets.

## Testing

### Test the two inputs and one output

In the Azure portal, press the 'test' button per input and output to see it the setup is connect. 

This will result in a green checkmark is the setup is correct for an input or output.

Both inputs and the output chould be able to connect. 

### Start the Stream analytics job

At this moment a sample job query is added to test the flow from iot hub to event hub with the stream analytics job in between. The reference data is not taken into account yet...

We will add the actual query in the last steps.

Navigate in the Azure portal to the stream analytics job.

Navigate to the Query page.

You see the current test job ASQL:

```
Select * into eventhuboutput from iothubinput
```

Navigate to the Overview page.

Start the job (starting ingesting messages 'now' is fine). 

See it starts succesfully, the state changes to 'Running'.

### Add an environment variable for the device connection string

We are going to send a device telemetry message using the test application seen in the folder 'deviceclient'.

This application needs the device connection string tom create a secure connection.

Please add the following environment variable on your development machine:

* key: ASADEVICECLIENT
* value: HostName=sql-reference-test-ih.azure-devices.net;DeviceId=testdevice;SharedAccessKey=KEY=

*Note*: Start the development tool only after this variable is added so it is read by the tooling.

### Send a telemetry message

To send a device telemetry message, start the test C# device client application seen in the folder 'deviceclient' in Visual Studio.

Run it.

See that the connection string is read.

See that the message is sent.

*Note*: The default message will not lead to an alert state. 

### See how the telemetry message arrives in the event hub

We test if the default message sent by a device is arring in the eventhub. 

*Note*: you need to have a 'Standard' tier event hub namespace when you need more than one consumer group per event hub. 

Navigate in the Azure portal to the eventhub namespace.

Navigate to the eventhub 'alerteh'.

Select the page 'Process data'.

Start the option 'Enable real time insights from events'.

*Note*: You get a message this viewer create an extra key and consumer group on the event hub.

You should see the telemetry message arrived, by now. Refresh the table using the 'refresh' button if needed.

Send a second telemetry message using the tooling.

This second message will arrive too.

*Note*: the event hub now contains two message which are not directly removed from this page. These JSON format differs from the actual alert messages. Mixing these messages will lead additional caused by the two message formats. This is not a problem. You can switch to the 'raw' visualization to overcome this table behavior.

 ## Load the stream analytics job query

We want to update and test the Azure Stream Analytics query with the actual alert job query, taking the reference data into account.

The new job query is made available in the 'asa extended reference data' folder.

### Stop the stream analytics job

Navigate in the Azure portal to the stream analytics job.

Stop the job. 

See it stops succesfully, the state changes to 'Stopped'.

Navigate to the Query page.

You see the current test job ASQL:

```
Select * into eventhuboutput from iothubinput
```

replace the job ASQL with the content of the file 'ASA-Sql-Reference script.asaql'.

Save the query using 'Save query' button.

Notice you get a green checkbox with the message 'Job ready to start'.

Navigate to the Overview page.

Start the job (starting ingesting messages 'now' is fine). 

See it starts succesfully, the state changes to 'Running'.

### Send telemetry messages to simulate alerts being raised

To send a device telemetry message having an alert situation, start or open the test C# device client application seen in the folder 'deviceclient' in Visual Studio.

*Note*: The default message will not lead to an alert state (the temperature is not high enough and the pressure is not low enough). 

Make a change in the code regarding the 'MessageBody':

* Change the pressure value from 1001 to 901. 

Run it.

See that the message is sent with the new value 901.

Now run it a few time more, repeat the same message multiple times.

### Check the alerts being raised in the eventhub

The expectation we will only see a limit number of messages. Perhaps the message is escalated one or twice but we do not get the same message for the same client more than once, even if we send a message dozens of times.

Navigate in the Azure portal to the eventhub namespace.

Navigate to the eventhub 'alerteh'.

Select the page 'Process data'.

Start the option 'Enable real time insights from events'.

Refresh the table using the 'refresh' button if needed.

You should see the arrival of al least two alert messages:

* Each message is bound for a certain client (see the email address) and showing the state of the alert: pressureAlertRaised, pressureAlertEscalated, pressureAlertEscalatedTwice.
* Each alert state is represented by two messages, due to the two email address subscribed to this device.

Notice the number of alerts is just a subset of the number of messages being sent.

### Send telemetry messages to simulate alerts being cleared

Open the test C# device client application seen in the folder 'deviceclient' in Visual Studio.

Undo the change in the code regarding the 'MessageBody':

* Change the pressure value from 901 to 1002. 

Run it.

See that the message is sent with the new value 1002.

Now run it a few time more, repeat the same message (without an alert situation) multiple times.

### Check the alerts being cleared in the eventhub

Navigate in the Azure portal to the eventhub namespace.

Navigate to the eventhub 'alerteh'.

Select the page 'Process data'.

Start the option 'Enable real time insights from events'.

Refresh the table using the 'refresh' button if needed.

You should see the arrival of two messages of the alert being cleared. Both messages represent an email to a client requesting an alert.

Notice no more messages are being sent, dispite the number of device messages (without an error situation).

## Change the reference data so device registration changes are picked up

### Change the content of the reference data table

Keep the Stream Analytics job running!

In the Azure portal, navigate to the 'referencedb' resource.

navigate to the 'Query editor (preview)' tab in the 'referencedb' resource.

Login using the name and password seen above.

Check the file 'SQL script.sql' in the folder '02 sqlserver' for the additional registration changes.

Execute only step 2/2:

- Add 1 row
- Remove 1 row
- Run the test query returning only 4 rows 
- Notice only clients D and E are interested in 'sensor-001' alerts 

Wait for a minute so the change is picked up.

### Send telemetry messages to simulate alerts being raised

Open the test C# device client application seen in the folder 'deviceclient' in Visual Studio.

Undo the change in the code regarding the 'MessageBody':

* Change the pressure value from 1002 to 903. 

Run it.

See that the message is sent with the new value 903.

### Check the alerts being cleared in the eventhub

Navigate in the Azure portal to the eventhub namespace.

Navigate to the eventhub 'alerteh'.

Select the page 'Process data'.

Start the option 'Enable real time insights from events'.

Refresh the table using the 'refresh' button if needed.

You should see the arrival of two messages of the alert being raised. Both messages represent an email to a client requesting an alert.

Notice that the name of one of these clients has changed according to the reference data. 

### Send telemetry messages to simulate alerts being cleared

Open the test C# device client application seen in the folder 'deviceclient' in Visual Studio.

Undo the change in the code regarding the 'MessageBody':

* Change the pressure value from 903 to 1003. 

Run it.

See that the message is sent with the new value 1003.

### Check the alerts being cleared in the eventhub

Navigate in the Azure portal to the eventhub namespace.

Navigate to the eventhub 'alerteh'.

Select the page 'Process data'.

Start the option 'Enable real time insights from events'.

Refresh the table using the 'refresh' button if needed.

You should see the arrival of two messages of the alert being cleared. Both messages represent an email sent to the latest registered clients.

## Conclusion

This flow demonstrates the power of using Azure Stream Analytics for alerts in a proper way, only on flanks and repeated when needed. 

