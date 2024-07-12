# Create Azure resources

## Prerequisites

The names seen must be used for reference. Please use your own set of names.

Next to creating resources using Azure CLI commands, other commands are used to inspect created resources and secrets needed further down the line.

To install and use Azure CLI, check this [documentation](https://learn.microsoft.com/cli/azure/install-azure-cli?WT.mc_id=AZ-MVP-5002324)

## Create a resource group

### Create a new resource group

```
az group create --name sql-reference-test-rg --location westeurope
```

## Create a storage account

### Create a new storage account

```
az storage account create --name sqlreferenceteststor --resource-group sql-reference-test-rg -l westeurope --sku Standard_LRS --kind StorageV2
```

### Get the storage account connection string

```
az storage account show-connection-string --name sqlreferenceteststor --resource-group sql-reference-test-rg
```

*Note*: This storage account connectionstring is needed by the stream analytics job for storing reference data.

## Create an IoT hub

### Create a new IoT hub

```
az iot hub create --name sql-reference-test-ih -g sql-reference-test-rg --location westeurope --sku S1 --partition-count 4
```

*Note*: The partition count is set to 4. Set it to 2 if you are using the free tier.

### Get the IoT hub connection string 

```
az iot hub connection-string show --hub-name sql-reference-test-ih --key-type primary
```

*Note*: This IoT hub connection string is needed by the stream analytics job IoT hub input to connect.

### Create an 'asa' consumer group on the default output stream

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

## Create an SQL Server and SQL database (plus firewall rules) 

### Create a new SQL Server

```
az sql server create --name sql-reference-test-srvr --resource-group sql-reference-test-rg --location northeurope --admin-user adminsql --admin-password demosecret
```

*Note*: Provide your own name and password. The complexity of the password will be checked upfront. These are needed by the stream analytics job reference input to connect.

### Create an SQL server firewall for Azure resources having access (needed for Stream Analytics)

```
az sql server firewall-rule create -g sql-reference-test-rg --server sql-reference-test-srvr -n azureaccess --start-ip-address 0.0.0.0 --end-ip-address 0.0.0.0
```

### Create an SQL server firewall for your own IP address having access (needed by you to add SQL statements)

```
az sql server firewall-rule create -g sql-reference-test-rg --server sql-reference-test-srvr -n myownipaddress --start-ip-address 88.111.55.88 --end-ip-address 88.111.55.88
```

If you want to know your local IP address, run this in a bash shell on your local machine:

```
ip=$(curl ipinfo.io/ip)
$ip
```

### Creating a SQL database within an SQL server

```
az sql db create --resource-group sql-reference-test-rg --server sql-reference-test-srvr --name referencedb --edition GeneralPurpose --family Gen5 --capacity 2 --zone-redundant false --free-limit-exhaustion-behavior AutoPause --free-limit false
```

*Note*: Here, I try to create a paid database. Technically, a free database should work too. You can create a maximum of one free SQL database per subscription. Fill in 'true' at the end for a free database (if applicable).

### Create the table and load the sample records

In the Azure portal, navigate to the 'referencedb' resource.

navigate to the 'Query editor (preview)' tab in the 'referencedb' resource.

Log in using the name and password seen above.

Check the file 'SQL script.sql' in the folder '02 sqlserver' for the first commands and inserts.

Execute only step 1/2:

- Create the table
- Add 7 rows
- Run the test query returning only 4 rows 
- Notice only clients A and D are interested in 'sensor-001' alerts 

## Create an Event hub namespace with Event hub

### Create a new Event hub namespace

```
az eventhubs namespace create --name sql-reference-test-ehns --resource-group sql-reference-test-rg -l westeurope --sku Standard
```

This creates a 'Standard' tier Event hub namespace.

*Note*: you need to have a 'Standard' tier Event hub namespace when you need more than one consumer group per event hub. 

### Get the RootManageSharedAccessKey of the Event hub namespace

```
az eventhubs namespace authorization-rule keys list --resource-group sql-reference-test-rg --namespace-name sql-reference-test-ehns --authorization-rule-name RootManageSharedAccessKey
```

*Note*: This Event hub namespace key is needed by the stream analytics job Event hub output to connect.

### Create an Event hub 

```
az eventhubs eventhub create --name alerteh --resource-group sql-reference-test-rg --namespace-name sql-reference-test-ehns --partition-count 4
```

*Note*: The same amount of partitions is filled in as in the IoT Hub to prevent 'funneling'.

## Create a stream analytics job, with inputs, output, and a test query

### Create a new stream analytics job

```
az stream-analytics job create --job-name sql-reference-test-asa --resource-group sql-reference-test-rg --location westeurope --compatibility-level "1.2" --data-locale "en-US" --content-storage-policy JobStorageAccount --job-storage-account authentication-mode=connectionstring account-name=sqlreferenceteststor account-key=key== --transformation name="basictransformation" streaming-units=1 query="SELECT * INTO eventhuboutput FROM iothubinput" --output-error-policy "Drop" --out-of-order-policy "Adjust" --order-max-delay 5 --arrival-max-delay 16
```

*Note*: Fill in storage account connection string secrets.

*Note*: This CLI command will create a 'Standard' SKU, not the new 'StandardV2'. If needed, this upgrade from 'Standard' to 'StandardV2' is advertised in the Azure portal overview page of the stream analytics job.

*Note*: The query just connects the IoT hub input to the Event hub output. This is to test the end to end connection first.

### Create an input named 'iothubinput' 

```
az stream-analytics input create --job-name sql-reference-test-asa --resource-group sql-reference-test-rg --input-name iothubinput --properties '{"type":"Stream","datasource":{"type":"Microsoft.Devices/IotHubs","properties":{"consumerGroupName":"asa","endpoint":"messages/events","iotHubNamespace":"sql-reference-test-ih","sharedAccessPolicyKey":"key=","sharedAccessPolicyName":"iothubowner"}},"serialization":{"type":"Json","encoding":"UTF8" } }'
```

*Note*: Fill in the IoT hub connection string secrets.

### Create an input named 'sqlreferenceinput'

```
az stream-analytics input create --job-name sql-reference-test-asa --resource-group sql-reference-test-rg --input-name sqlreferenceinput --properties '{ "type" : "Reference", "datasource": { "type": "Microsoft.Sql/Server/Database", "properties": { "authenticationMode": "ConnectionString", "database": "referencedb", "deltaSnapshotQuery": "", "fullSnapshotQuery": "SELECT DeviceId, ClientId, EmailAddress, IsEnabled FROM dbo.DeviceAlerts WHERE IsEnabled = 1", "password": "demosecret", "refreshRate": "0:01:00", "refreshType": "RefreshPeriodicallyWithFull", "server": "sql-reference-test-srvr", "user": "adminsql" } }, "serialization": { "type": "Json", "encoding": "UTF8" } }'
```

*Note*: Fill in the SQL server database secrets.

*Note*: This reference data is updated as a full table once a minute. This will create new storage account blobs every single minute. Check out the delta snapshot to overcome this.   

### Create an output named 'eventhuboutput'

```
az stream-analytics output create --job-name sql-reference-test-asa --resource-group sql-reference-test-rg --output-name eventhuboutput --datasource '{"type":"Microsoft.ServiceBus/EventHub", "properties": { "authenticationMode": "ConnectionString","eventHubName": "alerteh", "serviceBusNamespace": "sql-reference-test-ehns", "sharedAccessPolicyKey": "primarykey=", "sharedAccessPolicyName": "RootManageSharedAccessKey" } }' --serialization '{"type":"Json","properties":{"format":"LineSeparated","encoding":"UTF8"}}'
```

*Note*: Fill in Event hub namespace secrets.