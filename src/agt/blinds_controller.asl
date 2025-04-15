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
    makeArtifact("blinds", "org.hyperagents.jacamo.artifacts.wot.ThingArtifact", [Url], BlindId);
    focus(BlindId);
    .print("Created ThingArtifact for Blinds");
    
    // Create an MQTT artifact for communication
    makeArtifact("mqtt", "room.MQTTArtifact", ["blinds_controller"], MqttId);
    focus(MqttId);
    .print("Blinds controller connected to MQTT broker").

/*
 * Plan for handling received MQTT messages
 * Triggered by changes in observable properties from the MQTTArtifact
 */
+message(Source, Performative, Content)[artifact_id(ArtId)] : true <-
    .print("Received MQTT message from ", Source, ": ", Performative, " - ", Content);
    
    // Check if the message is a CFP for increasing illuminance
    if (Performative == "tell" & Content == "cfp(increase_illuminance)") {
        .print("Received CFP via MQTT for increasing illuminance");
        // Use the same CFP handling as with direct messaging
        !cfp(task("increase_illuminance"))[source(Source)];
    }.

+!handle_mqtt_acceptance(Source) : blinds("lowered") <-
    .print("Proposal accepted by ", Source, " via MQTT. Raising blinds to increase illuminance...");
    // Execute the task
    !raise_blinds;
    // Report task completion via MQTT
    sendMsg(Source, "inform_done", "task(\"increase_illuminance\"),\"natural_light\"").

+!handle_mqtt_acceptance(Source) : blinds("raised") <-
    .print("Received acceptance via MQTT but blinds already raised. Informing ", Source);
    sendMsg(Source, "inform", "blinds_already_raised").

/*
 * Plan for raising the blinds
 * This plan invokes the SetState action on the blinds with "raised" input
 */
+!raise_blinds : blinds("lowered") <-
    .print("Raising the blinds...");
    invokeAction("https://was-course.interactions.ics.unisg.ch/wake-up-ontology#SetState", ["raised"]);
    -+blinds("raised");
    .print("Blinds raised!");
    
    // Inform the personal assistant about the state change using KQML performative "tell"
    .send(personal_assistant, tell, blinds_status("raised")).
    
    // Send message via MQTT
    // sendMsg("personal_assistant", "inform", "blinds_status(raised)").

// If blinds are already raised, just acknowledge
+!raise_blinds : blinds("raised") <-
    .print("Blinds are already raised.").

/*
 * Plan for lowering the blinds
 * This plan invokes the SetState action on the blinds with "lowered" input
 */
+!lower_blinds : blinds("raised") <-
    .print("Lowering the blinds...");
    invokeAction("https://was-course.interactions.ics.unisg.ch/wake-up-ontology#SetState", ["lowered"]);
    -+blinds("lowered");
    .print("Blinds lowered!");
    
    // Inform the personal assistant about the state change using KQML performative "tell"
    .send(personal_assistant, tell, blinds_status("lowered")).
    
    // Send message via MQTT
    // sendMsg("personal_assistant", "inform", "blinds_status(lowered)").

// If blinds are already lowered, just acknowledge
+!lower_blinds : blinds("lowered") <-
    .print("Blinds are already lowered.").

/*
 * Plan for handling Contract Net Protocol Call for Proposals (CFP)
 * This responds with a proposal to increase illuminance using natural light if blinds are lowered
 * Otherwise, it refuses to participate
 */
+!cfp(task("increase_illuminance"))[source(Source)] : blinds("lowered") <-
    .print("Received CFP for increasing illuminance from ", Source);
    // Propose to raise blinds to increase illuminance with natural light
    .send(Source, tell, proposal("natural_light"));
    .print("Sent proposal to increase illuminance using natural light").

// If blinds are already raised, refuse to participate
+!cfp(task("increase_illuminance"))[source(Source)] : blinds("raised") <-
    .print("Received CFP for increasing illuminance from ", Source);
    .print("Blinds already raised. Refusing to participate.");
    .send(Source, tell, refuse(task("increase_illuminance"), "blinds_already_raised")).

/*
 * Plan for handling proposal acceptance
 */
+accept_proposal(task("increase_illuminance"))[source(Source)] : blinds("lowered") <-
    .print("Proposal accepted by ", Source, ". Raising blinds to increase illuminance...");
    // Execute the task
    !raise_blinds;
    // Report task completion
    .send(Source, tell, inform_done(task("increase_illuminance"), "natural_light")).

/*
 * Plan for handling proposal rejection
 */
+reject_proposal(task("increase_illuminance"))[source(Source)] : true <-
    .print("Proposal rejected by ", Source, ". Standing by.").// blinds controller agent

/* Import behavior of agents that work in CArtAgO environments */
{ include("$jacamoJar/templates/common-cartago.asl") }
