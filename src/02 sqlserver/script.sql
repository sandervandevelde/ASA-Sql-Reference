-- step 1/2

CREATE TABLE DeviceAlerts (
    DeviceId nvarchar(255),
    ClientId nvarchar(255),
    EmailAddress nvarchar(255),
    IsEnabled bit,
	PRIMARY KEY (DeviceId, ClientId)
)


select * from dbo.DeviceAlerts


INSERT INTO DeviceAlerts (DeviceId, ClientId, EmailAddress, IsEnabled)
VALUES ('sensor-001', 'ClientA', 'C.A@company.com', 1);

INSERT INTO DeviceAlerts (DeviceId, ClientId, EmailAddress, IsEnabled)
VALUES ('sensor-001', 'ClientB', 'C.B@company.com', 0);

INSERT INTO DeviceAlerts (DeviceId, ClientId, EmailAddress, IsEnabled)
VALUES ('sensor-001', 'ClientC', 'C.C@company.com', 0);

INSERT INTO DeviceAlerts (DeviceId, ClientId, EmailAddress, IsEnabled)
VALUES ('sensor-001', 'ClientD', 'C.D@company.com', 1);

INSERT INTO DeviceAlerts (DeviceId, ClientId, EmailAddress, IsEnabled)
VALUES ('sensor-002', 'ClientA', 'C.A@company.com', 1);

INSERT INTO DeviceAlerts (DeviceId, ClientId, EmailAddress, IsEnabled)
VALUES ('sensor-002', 'ClientB', 'C.B@company.com', 0);

INSERT INTO DeviceAlerts (DeviceId, ClientId, EmailAddress, IsEnabled)
VALUES ('sensor-002', 'ClientC', 'C.C@company.com', 1);


select DeviceId, ClientId, EmailAddress, IsEnabled from dbo.DeviceAlerts where IsEnabled = 1 


-- STEP 2/2

INSERT INTO DeviceAlerts (DeviceId, ClientId, EmailAddress, IsEnabled)
VALUES ('sensor-001', 'ClientE', 'C.E@company.com', 1);

delete from dbo.DeviceAlerts where (DeviceId = 'sensor-001') and (EmailAddress = 'C.A@company.com')


