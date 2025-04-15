// blinds controller agent

/* Initial beliefs */
// The agent has a belief about the location of the W3C Web of Thing (WoT) Thing Description (TD)
// that describes a Thing of type https://was-course.interactions.ics.unisg.ch/wake-up-ontology#Blinds (was:Blinds)
td("https://was-course.interactions.ics.unisg.ch/wake-up-ontology#Blinds", "https://raw.githubusercontent.com/Interactions-HSG/example-tds/was/tds/blinds.ttl").

// the agent initially believes that the blinds are "lowered"
blinds("lowered").

/* Initial goals */
// The agent has the goal to start
!start.

/*
 * Plan for reacting to the addition of the goal !start
 * Triggering event: addition of goal !start
 * Context: the agents believes that a WoT TD of a was:Blinds is located at Url
 * Body: greets the user, creates and focuses on an MQTTArtifact
*/
@start_plan
+!start : td("https://was-course.interactions.ics.unisg.ch/wake-up-ontology#Blinds", Url) <-
    .print("Blinds Controller starting up...");
    .print("Using Thing Description at: ", Url);
    .my_name(Name);
    .concat("mqtt_", Name, ArtifactName);
    // Try to create the artifact, or focus on it if it already exists
    makeArtifact(ArtifactName, "room.MQTTArtifact", [Name], MqttId);
    focus(MqttId);
    .print("Connected to MQTT broker as ", Name).

// Failure handling plan for artifact creation
-!start[error(action_failed), error_msg(Msg), env_failure_reason(makeArtifactFailure("artifact_already_present", ArtName))] : 
    td("https://was-course.interactions.ics.unisg.ch/wake-up-ontology#Blinds", Url) <-
    .print("Artifact ", ArtName, " already exists. Focusing on existing artifact.");
    lookupArtifact(ArtName, ArtId);
    focus(ArtId);
    .print("Connected to existing MQTT broker").

/*
 * Plan for handling received MQTT messages
 * Triggered by changes in observable properties from the MQTTArtifact
 */
+message_Count[artifact_id(ArtId)] : true <-
    .print("Received a new MQTT message");
    // Additional handling to be implemented in Task 4
    .

/*
 * Plan for handling direct Jason broadcast messages
 */
+mqtt_message(Performative, Content)[source(Source)] : true <-
    .print("Received Jason broadcast from ", Source, ": ", Performative, " - ", Content);
    // Additional handling to be implemented in Task 4
    .

/* Import behavior of agents that work in CArtAgO environments */
{ include("$jacamoJar/templates/common-cartago.asl") }
