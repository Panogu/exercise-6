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
+message(Source, Performative, Content)[artifact_id(ArtId)] : true <-
    .print("Received MQTT message for ", Source, ": ", Performative, " - ", Content);
    
    // Check if the message is a CFP for increasing illuminance
    if (Performative == "tell" & Content == "cfp(increase_illuminance)") {
        .print("Received CFP via MQTT for increasing illuminance");
        // Use the same CFP handling as with direct messaging
        !cfp(task("increase_illuminance"))[source(Source)];
    }.

+!handle_mqtt_acceptance(Source) : lights("off") <-
    .print("Proposal accepted by ", Source, " via MQTT. Turning on lights to increase illuminance...");
    // Execute the task
    !turn_on_lights;
    // Report task completion via MQTT
    sendMsg(Source, "inform_done", "task(\"increase_illuminance\"),\"artificial_light\"").

+!handle_mqtt_acceptance(Source) : lights("on") <-
    .print("Received acceptance via MQTT but lights are already on. Informing ", Source);
    sendMsg(Source, "inform", "lights_already_on").

/*
 * Plan for turning on the lights
 * This plan invokes the SetState action on the lights with "on" input
 */
+!turn_on_lights : lights("off") <-
    .print("Turning on the lights...");
    invokeAction("https://was-course.interactions.ics.unisg.ch/wake-up-ontology#SetState", ["on"]);
    -+lights("on");
    .print("Lights are now on!");
    
    // Inform the personal assistant about the state change using KQML performative "tell"
    .send(personal_assistant, tell, lights_status("on")).
    
    // Send message via MQTT
    // sendMsg("personal_assistant", "inform", "lights_status(on)").

// If lights are already on, just acknowledge
+!turn_on_lights : lights("on") <-
    .print("Lights are already on.").

/*
 * Plan for turning off the lights
 * This plan invokes the SetState action on the lights with "off" input
 */
+!turn_off_lights : lights("on") <-
    .print("Turning off the lights...");
    invokeAction("https://was-course.interactions.ics.unisg.ch/wake-up-ontology#SetState", ["off"]);
    -+lights("off");
    .print("Lights are now off!");
    
    // Inform the personal assistant about the state change using KQML performative "tell"
    .send(personal_assistant, tell, lights_status("off")).
    
    // Send message via MQTT
    // sendMsg("personal_assistant", "inform", "lights_status(off)").

// If lights are already off, just acknowledge
+!turn_off_lights : lights("off") <-
    .print("Lights are already off.").

/*
 * Plan for handling Contract Net Protocol Call for Proposals (CFP)
 * This responds with a proposal to increase illuminance using artificial light if lights are off
 * Otherwise, it refuses to participate
 */
+!cfp(task("increase_illuminance"))[source(Source)] : lights("off") <-
    .print("Received CFP for increasing illuminance from ", Source);
    // Propose to turn on lights to increase illuminance with artificial light
    .send(Source, tell, proposal("artificial_light"));
    .print("Sent proposal to increase illuminance using artificial light").

// If lights are already on, refuse to participate
+!cfp(task("increase_illuminance"))[source(Source)] : lights("on") <-
    .print("Received CFP for increasing illuminance from ", Source);
    .print("Lights already on. Refusing to participate.");
    .send(Source, tell, refuse(task("increase_illuminance"), "lights_already_on")).

/*
 * Plan for handling proposal acceptance
 */
+accept_proposal(task("increase_illuminance"))[source(Source)] : lights("off") <-
    .print("Proposal accepted by ", Source, ". Turning on lights to increase illuminance...");
    // Execute the task
    !turn_on_lights;
    // Report task completion
    .send(Source, tell, inform_done(task("increase_illuminance"), "artificial_light")).

/*
 * Plan for handling proposal rejection
 */
+reject_proposal(task("increase_illuminance"))[source(Source)] : true <-
    .print("Proposal rejected by ", Source, ". Standing by.").// lights controller agent

/* Import behavior of agents that work in CArtAgO environments */
{ include("$jacamoJar/templates/common-cartago.asl") }
