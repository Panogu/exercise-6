// personal assistant agent

/* Initial beliefs */
broadcast(jason).

/* Initial goals */
// The agent has the goal to start
!start.

/*
 * Plan for reacting to the addition of the goal !start
 * Triggering event: addition of goal !start
 * Context: true (the plan is always applicable)
 * Body: greets the user, creates and focuses on an MQTTArtifact
*/
@start_plan
+!start : true <- 
    .print("Personal Assistant starting up...");
    .my_name(Name);
    .concat("mqtt_", Name, ArtifactName);
    // Try to create the artifact, or focus on it if it already exists
    makeArtifact(ArtifactName, "room.MQTTArtifact", [Name], MqttId);
    focus(MqttId);
    .print("Connected to MQTT broker as ", Name).

// Failure handling plan for artifact creation
-!start[error(action_failed), error_msg(Msg), env_failure_reason(makeArtifactFailure("artifact_already_present", ArtName))] : true <-
    .print("Artifact ", ArtName, " already exists. Focusing on existing artifact.");
    lookupArtifact(ArtName, ArtId);
    focus(ArtId);
    .print("Connected to existing MQTT broker as ", Name).

/*
 * Plan for sending messages through MQTT
 * Usage: !send_mqtt(Agent, Performative, Content)
 */
+!send_mqtt(Agent, Performative, Content) : true <-
    .print("Sending MQTT message to ", Agent, ": ", Performative, " - ", Content);
    sendMsg(Agent, Performative, Content).

/*
 * Plan for broadcasting messages selectively
 * First tries Jason's broadcasting if broadcast(jason) is believed
 * Otherwise falls back to MQTT
 */
+!broadcast_message(Performative, Content) : broadcast(jason) <-
    .print("Broadcasting via Jason: ", Performative, " - ", Content);
    .broadcast(tell, mqtt_message(Performative, Content)).
    
+!broadcast_message(Performative, Content) : not broadcast(jason) <-
    .print("Broadcasting via MQTT: ", Performative, " - ", Content);
    sendMsg("all", Performative, Content).

/*
 * Plan for handling received MQTT messages
 * Triggered by changes in observable properties from the MQTTArtifact
 */
+message_Count[artifact_id(ArtId)] : true <-
    .print("Received a new MQTT message");
    // Additional handling to be implemented in Task 4
    .

/* Import behavior of agents that work in CArtAgO environments */
{ include("$jacamoJar/templates/common-cartago.asl") }
