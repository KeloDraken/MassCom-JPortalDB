USE master;
GO

CREATE DATABASE MassCom
GO

USE MassCom
GO

-- Creating Database structure

CREATE TABLE [dbo].[Property] (
    id INT IDENTITY(1,1) PRIMARY KEY,
    propertName NVARCHAR(255) NOT NULL,
	propertyAddress NVARCHAR(255) NOT NULL
)
GO

CREATE TABLE [dbo].[Users] (
    id INT IDENTITY(1,1) PRIMARY KEY,
    emailAddress NVARCHAR(255) NOT NULL,
	userName NVARCHAR(255) NOT NULL,
	userSurname NVARCHAR(255) NOT NULL,
	dateJoined DATETIME DEFAULT GETDATE(),
	propertyId INT NOT NULL

    CONSTRAINT FK_users_property FOREIGN KEY (propertyId) REFERENCES [dbo].[Property](id)
)
GO

CREATE TABLE [dbo].[UserTypes] (
    id INT IDENTITY(1,1) PRIMARY KEY,
    userId INT NOT NULL,
    userType NVARCHAR(50) NOT NULL,

    CONSTRAINT FK_usersPermissions_users FOREIGN KEY (userId) REFERENCES [dbo].[Users](id)
)
GO

CREATE TABLE [dbo].[EmailMessage] (
    id INT IDENTITY(1,1) PRIMARY KEY,
    body NVARCHAR(MAX) NOT NULL,
    emailSubject NVARCHAR(255) NOT NULL,
    sentDate DATETIME DEFAULT GETDATE(),
    senderId INT NOT NULL,
    recipientId INT NOT NULL,
	hasAttachments BIT NOT NULL DEFAULT 0,
	isDraft BIT NOT NULL DEFAULT 1,

    CONSTRAINT FK_email_messages_sender FOREIGN KEY (senderId) REFERENCES [dbo].[Users](id),
    CONSTRAINT FK_email_messages_users FOREIGN KEY (recipientId) REFERENCES [dbo].[Users](id)
)
GO

CREATE TABLE [dbo].[AllowedAttachmentFileTypes] (
    id INT IDENTITY(1,1) PRIMARY KEY,
    fileType NVARCHAR(50) NOT NULL,
    fileExtension NVARCHAR(20) NOT NULL,
)
GO

CREATE TABLE [dbo].[EmailAttachment] (
    id INT IDENTITY(1,1) PRIMARY KEY,
    fileTypeId INT NOT NULL,
    fileLocation NVARCHAR(MAX) NOT NULL,
    emailMessageId INT NOT NULL,

    CONSTRAINT FK_email_attachments_file_types FOREIGN KEY (fileTypeID) REFERENCES [dbo].[AllowedAttachmentFileTypes](id),
    CONSTRAINT FK_email_attachments_email_messages FOREIGN KEY (emailMessageID) REFERENCES [dbo].[EmailMessage](id)
)
GO

CREATE TABLE [dbo].[UserEmail] (
    id INT IDENTITY(1,1) PRIMARY KEY,
    userID INT NOT NULL,
    emailMessageID INT NOT NULL,
    received BIT NOT NULL  DEFAULT 0,
    datetimeReceived DATETIME DEFAULT GETDATE(),

    CONSTRAINT FK_user_messages_users FOREIGN KEY (userID) REFERENCES [dbo].[Users](id),
    CONSTRAINT FK_user_messages_email_messages FOREIGN KEY (emailMessageID) REFERENCES [dbo].[EmailMessage](id)
)
GO

-- End database structure creation

-- Stored procedures

CREATE PROCEDURE [dbo].[uspRegisterUser] (@name VARCHAR(255), @surname VARCHAR(255), @email VARCHAR(255), @propertyId INT, @userType VARCHAR)
AS
BEGIN
    DECLARE @userID INT;

    BEGIN TRANSACTION;
    BEGIN TRY
        INSERT INTO [dbo].[Users] (userName, userSurname, emailAddress, propertyID)
        VALUES (@name, @surname, @email, @propertyId);

        SET @userID = SCOPE_IDENTITY();

        INSERT INTO [dbo].[UserTypes] (userId, userType)
        VALUES (@userID, @userType);
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
    END CATCH;

    COMMIT TRANSACTION;
END
GO

CREATE PROCEDURE [dbo].[uspCreateProperty](@name VARCHAR(255), @address VARCHAR(255))
AS
BEGIN
    INSERT INTO [dbo].[Property] (propertName, propertyAddress)
    VALUES (@name, @address);
END
GO

CREATE PROCEDURE [dbo].[uspSendEmail] (@senderId INT, @recipientId INT, @subject VARCHAR(255), @body VARCHAR(MAX))
AS
BEGIN
	INSERT INTO [dbo].[EmailMessage] (senderId, recipientId, emailSubject, body) 
	VALUES (@senderId, @recipientId, @subject, @body)
END
GO

CREATE PROCEDURE [dbo].[uspEmailAttachment] (@emailId INT, @fileTypeID INT, @fileLocation VARCHAR(MAX))
AS
BEGIN
	INSERT INTO [dbo].[EmailAttachment] (emailMessageID, fileTypeID, fileLocation)
	VALUES (@emailId, @fileTypeID, @fileLocation)
END
GO

CREATE PROCEDURE [dbo].[uspGetUserEmails] (@userId INT)
AS
BEGIN
	SELECT * FROM [dbo].[vGetUserEmails] WHERE recipientID=@userId;
END
GO

-- end stored procedures

-- Start views
CREATE VIEW [dbo].[vGetUserEmails] 
AS
SELECT
	EmailMessage.id AS emailID,
	EmailMessage.hasAttachments AS HasAttachment,
    EmailMessage.recipientId,
    Users.userName AS recipientName,
    Users.userSurname AS recipientSurname,
    EmailMessage.emailSubject,
    EmailMessage.body,
    EmailMessage.sentDate
FROM 
    [dbo].[EmailMessage]
    INNER JOIN Users ON EmailMessage.recipientId = Users.id
GO

CREATE VIEW [dbo].[vGetEmailsWithAttachments]
AS
SELECT
	EmailMessage.id AS emailId,
	EmailMessage.emailSubject, 
	EmailMessage.body,
	EmailMessage.recipientId,
	Users.emailAddress AS recipientEmailAddress,
	EmailAttachment.fileTypeId AS fileTypeID,
	AllowedAttachmentFileTypes.fileType AS fileType,
	EmailAttachment.fileLocation
FROM 
	[dbo].[EmailMessage]
	INNER JOIN Users ON EmailMessage.recipientId = Users.id
	INNER JOIN EmailAttachment ON EmailAttachment.emailMessageId = EmailMessage.id
	INNER JOIN AllowedAttachmentFileTypes ON AllowedAttachmentFileTypes.id = fileTypeId
WHERE EmailMessage.hasAttachments = 1
GO


CREATE VIEW [dbo].[vGetUser]
AS
SELECT
	Users.id AS userID,
	Users.userName,
	Users.userSurname,
	Users.emailAddress,
	Users.dateJoined,
	Property.propertName,
	UserTypes.userType
FROM 
	[dbo].[Users]
	INNER JOIN Property ON Property.id = Users.propertyId
	INNER JOIN UserTypes ON UserTypes.userId = Users.id
GO
-- End views

-- Functions
CREATE FUNCTION [dbo].[udfGetRecipientEmail] (@emailId INT)
RETURNS NVARCHAR(255)
AS
BEGIN
    DECLARE @recipientEmail NVARCHAR(255)

    SELECT @recipientEmail = emailAddress
    FROM Users
    WHERE id = (SELECT recipientId FROM [dbo].[EmailMessage] WHERE id = @emailId)

    RETURN @recipientEmail
END
GO

CREATE FUNCTION [dbo].[udfGetEmailCount] (@userId INT)
RETURNS INT
AS
BEGIN
	DECLARE @emailCount INT
	SELECT @emailCount = COUNT(*)
	FROM [dbo].[UserEmail]
	WHERE userId = @userId AND received = 1

	RETURN @emailCount
END
GO
-- end functions


-- Inserts
INSERT INTO [dbo].[Property] (propertName, propertyAddress)
VALUES 
('BBD - Johannesburg', 'The Zone Boulevard, Cnr Cradock &, Tyrwhitt Ave, Rosebank, Johannesburg, 2196'),
('Ranprop Residential Projects', '23 Cradock Avenue, Rosebank, Johannesburg'),
('HB Realty Office','39 Sturdee Avenue, Rosebank, Johannesburg'),
('Aucor Property Johannesburg','22a Baker Street, Rosebank, Johannesburg')
GO

EXEC [dbo].[uspRegisterUser] @name = 'John', @surname = 'Doe', @email = 'johndoe1@gmail.com', @propertyId = 1, @userType = 'Resident';
EXEC [dbo].[uspRegisterUser] @name = 'Jane', @surname = 'Doe', @email = 'janedoe1@gmail.com', @propertyId = 1, @userType = 'Admin';
EXEC [dbo].[uspRegisterUser] @name = 'John', @surname = 'Smith', @email = 'johnsmith1@gmail.com', @propertyId = 2, @userType = 'Resident';
EXEC [dbo].[uspRegisterUser] @name = 'Jane', @surname = 'Smith', @email = 'janesmith1@gmail.com', @propertyId = 2, @userType = 'Resident';
EXEC [dbo].[uspRegisterUser] @name = 'Michael', @surname = 'Johnson', @email = 'michaeljohnson1@gmail.com', @propertyId = 3, @userType = 'Resident';
EXEC [dbo].[uspRegisterUser] @name = 'Emily', @surname = 'Johnson', @email = 'emilyjohnson1@gmail.com', @propertyId = 3, @userType = 'Admin';


INSERT INTO [dbo].[AllowedAttachmentFileTypes] (fileType, fileExtension)
VALUES 
('JPEG image', '.jpg'),
('PNG image', '.png'),
('PDF document', '.pdf'),
('Microsoft Word document', '.docx')
GO

-- Insert email without attachments
EXEC [dbo].[uspSendEmail] @senderId = 2, @recipientId = 1, @subject = 'Rent Reminder' , @body = 'Dear Tenant,\n\nJust a friendly reminder to pay your rent on time this month. If you have any issues, please let me know.\n\nBest regards,\nLandlord'
EXEC [dbo].[uspSendEmail]  @senderId = 6, @recipientId = 1, @subject = 'Appreciation', @body = 'Dear Tenant,\n\nThank you for taking care of the property and being a great tenant.\n\nBest regards,\nLandlord'
EXEC [dbo].[uspSendEmail] @senderId = 6, @recipientId = 1, @subject = 'Property Inspection', @body = 'Dear Tenant,\n\nI wanted to inform you that I will be conducting an inspection of the property next week. Please let me know if there are any specific times that work better for you.\n\nBest regards,\nLandlord'
EXEC [dbo].[uspSendEmail] @senderId = 2, @recipientId = 3, @subject = 'Check-in', @body = 'Dear Tenant,\n\nI wanted to reach out to see if you have any concerns or issues with the property. I am here to help.\n\nBest regards,\nLandlord'
EXEC [dbo].[uspSendEmail] @senderId = 2, @recipientId = 5, @subject = 'Maintenance Request', @body = 'Dear Tenant,\n\nPlease let me know if you need any repairs or maintenance done in the property. I am here to help.\n\nBest regards,\nLandlord'

-- Insert email with attachments
INSERT INTO [dbo].[EmailMessage] (body, emailSubject, senderId, recipientId, hasAttachments, isDraft)
VALUES
('Dear Tenant,\n\nPlease find attached the lease agreement for your reference.\n\nBest regards,\nLandlord', 'Lease Agreement', 2, 1, 1, 0),
('Dear Tenant,\n\nPlease find attached the latest statement of your rent payments.\n\nBest regards,\nLandlord', 'Rent Statement', 6, 4, 1, 0),
('Dear Tenant,\n\nPlease find attached the new rules and regulations for the property.\n\nBest regards,\nLandlord', 'Property Rules and Regulations', 2, 1, 1, 0),
('Dear Tenant,\n\nPlease find attached the updated contact information for emergency services.\n\nBest regards,\nLandlord', 'Emergency Services', 6, 3, 1, 0),
('Dear Tenant,\n\nPlease find attached the latest newsletter for the property.\n\nBest regards,\nLandlord', 'Property Newsletter', 2, 3, 1, 0)
GO

INSERT INTO [dbo].[EmailAttachment] (fileTypeId, fileLocation, emailMessageId)
VALUES
(3, 'https://files.example.com/leaseAgreement.pdf', 5),
(3, 'https://files.example.com/rentStatement.pdf', 6),
(3, 'https://files.example.com/propertyRulesRegulations.pdf', 7),
(3, 'https://files.example.com/emergencyServices.pdf', 8),
(3, 'https://files.example.com/propertyNewsletter.pdf', 9)
GO

-- End inserts
