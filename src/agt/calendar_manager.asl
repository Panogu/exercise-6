// calendar manager agent

/* Initial beliefs */
// The agent has a belief about the location of the W3C Web of Thing (WoT) Thing Description (TD)
// that describes a Thing of type https://was-course.interactions.ics.unisg.ch/wake-up-ontology#CalendarService (was:CalendarService)
td("https://was-course.interactions.ics.unisg.ch/wake-up-ontology#CalendarService", "https://raw.githubusercontent.com/Interactions-HSG/example-tds/was/tds/calendar-service.ttl").

/* Initial goals */
// The agent has the goal to start
!start.

/*
 * Plan for reacting to the addition of the goal !start
 * Triggering event: addition of goal !start
 * Context: the agents believes that a WoT TD of a was:CalendarService is located at Url
 * Body: creates a ThingArtifact for the calendar service and focuses on it
 * Also creates and focuses on an MQTT artifact for communication
*/
@start_plan
+!start : td("https://was-course.interactions.ics.unisg.ch/wake-up-ontology#CalendarService", Url) <-
    .print("Calendar Manager starting up...");
    .print("Using Thing Description at: ", Url);
    
    // Create a ThingArtifact based on the TD
    makeArtifact("calendar", "wot.ThingArtifact", [Url], CalId);
    focus(CalId);
    .print("Created ThingArtifact for Calendar Service");
    
    // Create an MQTT artifact for communication
    .my_name(Name);
    .concat("mqtt_", Name, ArtifactName);
    makeArtifact(ArtifactName, "room.MQTTArtifact", [Name], MqttId);
    focus(MqttId);
    .print("Connected to MQTT broker as ", Name);
    
    // Start checking for upcoming events
    !check_calendar.

// Failure handling plan for MQTT artifact creation
-!start[error(action_failed), error_msg(Msg), env_failure_reason(makeArtifactFailure("artifact_already_present", ArtName))] :
    td("https://was-course.interactions.ics.unisg.ch/wake-up-ontology#CalendarService", Url) <-
    .print("MQTT Artifact ", ArtName, " already exists. Focusing on existing artifact.");
    lookupArtifact(ArtName, ArtId);
    focus(ArtId);
    .print("Connected to existing MQTT broker");
    
    // Create a ThingArtifact based on the TD
    makeArtifact("calendar", "wot.ThingArtifact", [Url], CalId);
    focus(CalId);
    .print("Created ThingArtifact for Calendar Service");
    
    // Start checking for upcoming events
    !check_calendar.

/*
 * Plan for checking the calendar for upcoming events
 * The plan reads the upcoming event property and processes the result
 */
@check_calendar_plan
+!check_calendar : true <-
    .print("Checking calendar for upcoming events...");
    readProperty("Read upcoming event", Result);
    .print("Calendar result: ", Result);
    
    // Process the result and update belief
    -+upcoming_event(Result);
    
    // If there's an upcoming event "now", notify other agents
    if (Result == "now") {
        .print("Upcoming event NOW! Notifying personal assistant...");
        !notify_upcoming_event(Result);
    }
    
    // Check again after some time
    .wait(10000);  // Wait 10 seconds before checking again
    !check_calendar.

/*
 * Plan for notifying about upcoming events
 */
+!notify_upcoming_event(Event) : true <-
    .print("Sending notification about upcoming event: ", Event);
    sendMsg("personal_assistant", "inform", "upcoming_event(now)").

// Failure handling for readProperty
-!check_calendar[error(E)] : true <-
    .print("Error checking calendar: ", E);
    .wait(5000);  // Wait a bit before trying again
    !check_calendar.

/* Import behavior of agents that work in CArtAgO environments */
{ include("$jacamoJar/templates/common-cartago.asl") }
