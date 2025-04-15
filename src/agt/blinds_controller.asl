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
    
    // Create a ThingArtifact based on the TD
    makeArtifact("blinds", "wot.ThingArtifact", [Url], BlindId);
    focus(BlindId);
    .print("Created ThingArtifact for Blinds");
    
    // Create an MQTT artifact for communication
    .my_name(Name);
    .concat("mqtt_", Name, ArtifactName);
    makeArtifact(ArtifactName, "room.MQTTArtifact", [Name], MqttId);
    focus(MqttId);
    .print("Connected to MQTT broker as ", Name).

// Failure handling plan for MQTT artifact creation
-!start[error(action_failed), error_msg(Msg), env_failure_reason(makeArtifactFailure("artifact_already_present", ArtName))] : 
    td("https://was-course.interactions.ics.unisg.ch/wake-up-ontology#Blinds", Url) <-
    .print("MQTT Artifact ", ArtName, " already exists. Focusing on existing artifact.");
    lookupArtifact(ArtName, ArtId);
    focus(ArtId);
    .print("Connected to existing MQTT broker");
    
    // Create a ThingArtifact based on the TD
    makeArtifact("blinds", "wot.ThingArtifact", [Url], BlindId);
    focus(BlindId);
    .print("Created ThingArtifact for Blinds").

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

/*
 * Plan for raising the blinds
 * This plan invokes the SetState action on the blinds with "raised" input
 */
+!raise_blinds : blinds("lowered") <-
    .print("Raising the blinds...");
    invokeAction("Set the blinds state", ["raised"], Result);
    .print("Blinds raise action result: ", Result);
    -+blinds("raised");
    .broadcast(tell, blinds_status("raised")).

// If blinds are already raised, just acknowledge
+!raise_blinds : blinds("raised") <-
    .print("Blinds are already raised.").

/*
 * Plan for lowering the blinds
 * This plan invokes the SetState action on the blinds with "lowered" input
 */
+!lower_blinds : blinds("raised") <-
    .print("Lowering the blinds...");
    invokeAction("Set the blinds state", ["lowered"], Result);
    .print("Blinds lower action result: ", Result);
    -+blinds("lowered");
    .broadcast(tell, blinds_status("lowered")).

// If blinds are already lowered, just acknowledge
+!lower_blinds : blinds("lowered") <-
    .print("Blinds are already lowered.").

/* Import behavior of agents that work in CArtAgO environments */
{ include("$jacamoJar/templates/common-cartago.asl") }
