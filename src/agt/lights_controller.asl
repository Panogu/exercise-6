// lights controller agent

/* Initial beliefs */
// The agent has a belief about the location of the W3C Web of Thing (WoT) Thing Description (TD)
// that describes a Thing of type https://was-course.interactions.ics.unisg.ch/wake-up-ontology#Lights (was:Lights)
td("https://was-course.interactions.ics.unisg.ch/wake-up-ontology#Lights", "https://raw.githubusercontent.com/Interactions-HSG/example-tds/was/tds/lights.ttl").

// The agent initially believes that the lights are "off"
lights("off").

/* Initial goals */
// The agent has the goal to start
!start.

/*
 * Plan for reacting to the addition of the goal !start
 * Triggering event: addition of goal !start
 * Context: the agents believes that a WoT TD of a was:Lights is located at Url
 * Body: greets the user, creates and focuses on an MQTTArtifact
*/
@start_plan
+!start : td("https://was-course.interactions.ics.unisg.ch/wake-up-ontology#Lights", Url) <-
    .print("Lights Controller starting up...");
    .print("Using Thing Description at: ", Url);
    
    // Create a ThingArtifact based on the TD
    makeArtifact("lights", "org.hyperagents.jacamo.artifacts.wot.ThingArtifact", [Url], LightId);
    focus(LightId);
    .print("Created ThingArtifact for Lights");
    
    // Create an MQTT artifact for communication
    .my_name(Name);
    .concat("mqtt_", Name, ArtifactName);
    makeArtifact(ArtifactName, "room.MQTTArtifact", [Name], MqttId);
    focus(MqttId);
    .print("Connected to MQTT broker as ", Name).

// Failure handling plan for MQTT artifact creation
-!start[error(action_failed), error_msg(Msg), env_failure_reason(makeArtifactFailure("artifact_already_present", ArtName))] : 
    td("https://was-course.interactions.ics.unisg.ch/wake-up-ontology#Lights", Url) <-
    .print("MQTT Artifact ", ArtName, " already exists. Focusing on existing artifact.");
    lookupArtifact(ArtName, ArtId);
    focus(ArtId);
    .print("Connected to existing MQTT broker");
    
    // Create a ThingArtifact based on the TD
    makeArtifact("lights", "wot.ThingArtifact", [Url], LightId);
    focus(LightId);
    .print("Created ThingArtifact for Lights").

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
 * Plan for turning on the lights
 * This plan invokes the SetState action on the lights with "on" input
 */
+!turn_on_lights : lights("off") <-
    .print("Turning on the lights...");
    invokeAction("Set the lights state", ["on"], Result);
    .print("Lights turn on action result: ", Result);
    -+lights("on");
    
    // Inform the personal assistant about the state change using KQML performative "tell"
    .send(personal_assistant, tell, lights_status("on"));
    
    // Also broadcast via Jason's internal mechanism
    .broadcast(tell, lights_status("on"));
    
    // Also send via MQTT as a backup communication channel
    sendMsg("personal_assistant", "inform", "lights_status(on)").

// If lights are already on, just acknowledge
+!turn_on_lights : lights("on") <-
    .print("Lights are already on.").

/*
 * Plan for turning off the lights
 * This plan invokes the SetState action on the lights with "off" input
 */
+!turn_off_lights : lights("on") <-
    .print("Turning off the lights...");
    invokeAction("Set the lights state", ["off"], Result);
    .print("Lights turn off action result: ", Result);
    -+lights("off");
    
    // Inform the personal assistant about the state change using KQML performative "tell"
    .send(personal_assistant, tell, lights_status("off"));
    
    // Also broadcast via Jason's internal mechanism
    .broadcast(tell, lights_status("off"));
    
    // Also send via MQTT as a backup communication channel
    sendMsg("personal_assistant", "inform", "lights_status(off)").

// If lights are already off, just acknowledge
+!turn_off_lights : lights("off") <-
    .print("Lights are already off.").

/* Import behavior of agents that work in CArtAgO environments */
{ include("$jacamoJar/templates/common-cartago.asl") }