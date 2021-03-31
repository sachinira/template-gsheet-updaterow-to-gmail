import ballerina/http;
import ballerina/log;
import ballerinax/googleapis_drive as drive;
import ballerinax/googleapis_gmail as gmail;
import ballerinax/googleapis_sheets as sheets;
import ballerinax/googleapis_sheets.'listener as sheetsListener;

// Event Trigger class
public class EventTrigger {
    public isolated function onNewSheetCreatedEvent(string fileId) {}

    public isolated function onSheetDeletedEvent(string fileId) {}

    public isolated function onFileUpdateEvent(string fileId) {}
}

// Google Drive/Sheets listener configuration
configurable http:OAuth2DirectTokenConfig & readonly driveOauthConfig = ?;
configurable int & readonly port = ?;
configurable string & readonly callbackURL = ?;

// Google Sheet client configuration
configurable http:OAuth2DirectTokenConfig & readonly sheetOauthConfig = ?;
configurable string & readonly spreadsheetId = ?;
configurable string & readonly workSheetName = ?;

// Gmail client configuration
configurable http:OAuth2DirectTokenConfig & readonly gmailOauthConfig = ?;
configurable string & readonly cc = ?;
configurable string & readonly subject = ?;
configurable string & readonly messageBody = ?;
configurable string & readonly contentType = ?;

// Initialize Google Drive client 
drive:Configuration driveClientConfiguration = {
    clientConfig: driveOauthConfig
};

// Initialize Gmail client 
gmail:GmailConfiguration gmailClientConfiguration = {
    oauthClientConfig: gmailOauthConfig
};

// Initialize Google Sheets client 
sheets:SpreadsheetConfiguration spreadsheetConfig = {
    oauthClientConfig: sheetOauthConfig
};

// Initialize Google Sheets listener 
sheetsListener:SheetListenerConfiguration congifuration = {
    port: port,
    callbackURL: callbackURL,
    driveClientConfiguration: driveClientConfiguration,
    eventService: new EventTrigger()
};

// Create Gmail client.
gmail:Client gmailClient = new (gmailClientConfiguration);

// Create Google Sheets client.
sheets:Client spreadsheetClient = check new (spreadsheetConfig);

// Create Google Sheets listener client.
listener sheetsListener:GoogleSheetEventListener gSheetListener = new (congifuration);

service / on gSheetListener {
    resource function post onEdit (http:Caller caller, http:Request request) returns error? {
        sheetsListener:EventInfo eventInfo = check gSheetListener.getOnEditEventType(caller, request);
        
        if (eventInfo?.eventType == sheetsListener:UPDATE_ROW && eventInfo?.editEventInfo != ()) {
            // Get the updated row position
            int? startingRowPosition = eventInfo?.editEventInfo?.startingRowPosition;

            if (startingRowPosition is int) {
                // Get the Email address
                (string|int|float) emailAddress = check spreadsheetClient->getCell(spreadsheetId, workSheetName, 
                    string `D${startingRowPosition}`);

                // Get the updated Values 
                (int|string|float)[][]? updatedData = eventInfo?.editEventInfo?.newValues;

                if (updatedData is (int|string|float)[][]) {
                   // Send email
                    gmail:MessageRequest messageRequest = {};
                    messageRequest.recipient = emailAddress.toString();
                    messageRequest.sender = "me";
                    messageRequest.subject = subject;
                    messageRequest.cc = cc;
                    messageRequest.messageBody = messageBody + updatedData[0][0].toString();
                    messageRequest.contentType = contentType;

                    [string, string]|error sendMessageResponse = checkpanic gmailClient->sendMessage("me", 
                        messageRequest);
                    if (sendMessageResponse is [string, string]) {
                        // If successful print it"
                        log:print("Message have sucessfully sent");
                    } else {
                        // If unsuccessful, print the error returned.
                        log:printError(sendMessageResponse.message());
                    }
                }
            }
        }
    }
}
