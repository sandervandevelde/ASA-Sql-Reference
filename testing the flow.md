# Testing the flow

## Prerequisites

All Azure resources have been created already.

## Testing the telemetry message flow end-to-end using a basic Stream Analytics query

Before we dive into the actual alert query, we first test the current device client -> IoT hub -> Stream Analytics -> Event hub flow.

### Test if the two inputs and one output are configured correctly

The Azure portal offers the ability to test input and output connectivity.

In the Azure portal, first navigate to either the Stream Analytics input or output page. Then switch.

Press the 'test' button per input and output to see if the setup is connected. 

This will result in a green checkmark if the setup is correct per input and/or output.

Both inputs and the output should be able to connect. 

### Start the Stream Analytics job

Currently, a sample job query is added to test the flow from an IoT hub to an Event hub with the stream analytics job in between. 

*Note*: The reference data is not taken into account yet.

*Note*: We will add the actual query with the alert logic in the last steps of this flow.

Navigate in the Azure portal to the stream analytics job.

Navigate to the Query page.

You see the current test job ASQL:

```
SELECT * INTO eventhuboutput FROM iothubinput
```

Navigate to the Overview page.

Start the job (starting ingesting messages 'now' is fine). 

See it starts successfully, and the state changes to 'Running'.

### Add an environment variable for the device connection string

We are going to send a device telemetry message using the test application seen in the folder 'deviceclient'.

This application needs the device connection string to create a secure connection (to prevent checking in the connection string into version control).

Please add the following environment variable on your development machine:

* key: ASADEVICECLIENT
* value: HostName=sql-reference-test-ih.azure-devices.net;DeviceId=testdevice;SharedAccessKey=KEY=

*Note*: Start the development tool (Visual Studio) only after this variable is added so it is read by the tooling.

### Send a telemetry message

To send a device telemetry message, start the test C# device client application seen in the folder 'deviceclient' in Visual Studio.

Run it unchanged.

See that the connection string is read.

See that the message is sent.

*Note*: The default message will not lead to an alert state. 

### See how the telemetry message arrives in the Event hub

We test if the default message sent by a device is arriving in the Event hub. 

*Note*: you need to have a 'Standard' tier Event hub namespace when you need more than one consumer group per Event hub. This is especially true when you add logic consuming the alert arriving in the Event hub.

Navigate in the Azure portal to the Event hub namespace.

Navigate to the Event hub 'alerteh'.

Select the page 'Process data'.

Start the option 'Enable real time insights from events'.

*Note*: You get a message that this viewer tool creates an extra key and consumer group on the Event hub.

You should see the telemetry message arrived, by now. Refresh the table using the 'refresh' button if needed.

Send a second telemetry message using the tooling.

This second message will arrive too.

*Note*: the Event hub now contains two messages which are not directly removed from this page. This JSON format differs from the actual alert messages. Mixing these messages will lead to additional columns caused by combining the two message formats. This is not a problem. You can switch to the 'raw' visualization to overcome this table behavior.

Note: By changing the Event Hub retention time to just one hour (check the configuration page) you can have older messages automatically removed from the Event Hub internal queue.

 ## Load the stream analytics job query having alert logic

We now update and test the Azure Stream Analytics query with the actual alert job query, taking the reference data into account.

The new job query is made available in the 'asa extended reference data' folder.

### Stop the stream analytics job

Before we can alter the query, we need to stop the query.

Navigate in the Azure portal to the stream analytics job.

Stop the job. 

See it stops successfully, and the state changes to 'Stopped'.

Navigate to the Query page.

You see the current test job ASQL query:

```
SELECT * INTO eventhuboutput FROM iothubinput
```

Replace the job ASQL with the content of the file 'ASA-Sql-Reference script.asaql'.

Save the query using the 'Save query' button.

Notice you get a green checkmark with the message 'Job ready to start'.

Navigate to the Overview page.

Start the job (starting ingesting messages 'now' is fine). 

See it starts successfully, and the state changes to 'Running'.

### Send telemetry messages to simulate alerts being raised

To send a device telemetry message having an alert situation, start or open the test C# device client application seen in the folder 'deviceclient' in Visual Studio.

*Note*: The default message will not lead to an alert state (the temperature is not high enough and the pressure is not low enough). 

Make a change in the code regarding the 'MessageBody':

* Change the pressure value from 1001 to 901. 

Run it.

See that the message is sent with the new value 901.

Now run it a few times more, and repeat the same message multiple times.

### Check the alerts being raised in the Event hub

The expectation is that we will only see less alerts than messages sent. Perhaps a message is escalated once or twice but we do not get the same message for the same client more than once, even if we send a message dozens of times.

Navigate in the Azure portal to the Event hub namespace.

Navigate to the Event hub 'alerteh'.

Select the page 'Process data'.

Start the option 'Enable real time insights from events'.

Refresh the table using the 'refresh' button if needed.

You should see the arrival of at least two alert messages.

This is the situation:

* Each message is bound for a certain client (see the email address) and shows the state of the alert: pressureAlertRaised, pressureAlertEscalated, pressureAlertEscalatedTwice.
* Each alert state is represented by two messages, due to the two email addresses subscribed to this device.

Notice the number of alerts is just a subset of the number of messages being sent.

### Send telemetry messages to simulate alerts being cleared

Open the test C# device client application seen in the folder 'deviceclient' in Visual Studio.

Undo the change in the code regarding the 'MessageBody':

* Change the pressure value from 901 to 1002. 

Run it.

See that the message is sent with the new value 1002.

Now run it a few times more, and repeat the same message (without an alert situation) multiple times.

### Check the alerts being cleared in the Event hub

Navigate in the Azure portal to the Event hub namespace.

Navigate to the Event hub 'alerteh'.

Select the page 'Process data'.

Start the option 'Enable real time insights from events'.

Refresh the table using the 'refresh' button if needed.

You should see the arrival of two messages of the alert being cleared. Both messages represent an email to a client requesting an alert.

Notice no more messages are being sent, despite the number of device messages (without an error situation).

## Change the reference data so device registration changes are picked up

Let's update the SQL database table and see how the email selection changes automatically.

### Change the content of the reference data table

*Keep the Stream Analytics job running!*

In the Azure portal, navigate to the 'referencedb' resource.

Navigate to the 'Query editor (preview)' tab in the 'referencedb' resource.

Log in using the SQL database name and password seen above.

Check the file 'SQL script.sql' in the folder '02 sqlserver' for the additional registration changes.

Execute only step 2/2.

This shows for device 'sensor-001':

- Adds 1 row
- Removes 1 row
- Runs the test query returning only 4 rows 
- Notice only clients D and E are interested in 'sensor-001' alerts 

Wait a minute so the change is picked up.

### Send telemetry messages to simulate alerts being raised

Open the test C# device client application seen in the folder 'deviceclient' in Visual Studio.

Undo the change in the code regarding the 'MessageBody':

* Change the pressure value from 1002 to 903. 

Run it.

See that the message is sent with the new value 903.

### Check the alerts being cleared in the Event hub

Navigate in the Azure portal to the Event hub namespace.

Navigate to the Event hub 'alerteh'.

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

### Check the alerts being cleared in the Event hub

Navigate in the Azure portal to the Event hub namespace.

Navigate to the Event hub 'alerteh'.

Select the page 'Process data'.

Start the option 'Enable real time insights from events'.

Refresh the table using the 'refresh' button if needed.

You should see the arrival of two messages of the alert being cleared. Both messages represent an email sent to the latest registered clients.

### Stop the stream analytics job

We are ready with our tests regarding the new alerting flow. 

Once you are ready, it's recommended to stop the job to save Azure credits.

Navigate in the Azure portal to the stream analytics job.

Stop the job. 

See it stops successfully, the state changes to 'Stopped'.

## Clean up resources

Keeping resources running can lead to extra Azure credits consumption.

Check the following resources:

* IoT Hub (Free or Standard tier)
* Storage account
* EventHub (Basic or Standard tier)
* Stream Analytics job (Standard or StandardV2 tier)
* SQL Server and database (Free or paid tier)

## Points of attention

We do not make use of the deltaSnapshotQuery when working with reference data. So, the job creates a new reference table every time the timer is triggered. These are then stored in a container in the storage account.

This results in more storage consumption over time than needed. Please check the delta snapshot option or keep removing unneeded old reference data.

The CLI does not seem to understand the 'StandardV2' tier of a Stream Analytics job. This can be fixed by hand.

We see a lot of connection strings here to tie Azure resources together. In production, please try to use managed identities as much as possible.

## Conclusion

This flow demonstrates the power of using Azure Stream Analytics for alerts in a proper way, only on flanks, and repeated when needed. 

