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
 * Body: greets the user, creates and focuses on MQTTArtifact
*/
@start_plan
+!start : true <- 
    .print("Personal Assistant starting up...");
    .my_name(Name);
    
    // Create and focus on MQTT Artifact
    .concat("mqtt_", Name, MqttArtName);
    makeArtifact(MqttArtName, "room.MQTTArtifact", [Name], MqttId);
    focus(MqttId);
    .print("Connected to MQTT broker as ", Name).

// Failure handling plan for MQTT artifact creation
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
 * General plan for sending messages
 * Usage: !send_message(Agent, Performative, Content)
 */
+!send_message(Agent, Performative, Content) : true <-
    !send_mqtt(Agent, Performative, Content).

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
 * Plan for handling messages received via Jason's messaging system
 * This plan reacts to owner state changes from the wristband manager
 */
+owner_state(State)[source(Source)] : true <-
    .print("Received owner state update from ", Source, ": ", State);
    // Add appropriate reactions to different owner states
    if (State == "awake") {
        .print("Owner has woken up. Initiating wake-up sequence...");
        !wake_up_sequence;
    } elif (State == "asleep") {
        .print("Owner has fallen asleep. Initiating sleep sequence...");
        !sleep_sequence;
    }.

/*
 * Plan for handling messages received via Jason's messaging system
 * This plan reacts to upcoming calendar events
 */
+upcoming_event(Event)[source(Source)] : true <-
    .print("Received calendar event update from ", Source, ": ", Event);
    // Add appropriate reactions to different event states
    if (Event == "now") {
        .print("Event happening now! Alerting owner...");
        !alert_owner_event;
    }.

/*
 * Plan for handling messages received via Jason's messaging system
 * This plan reacts to blinds status updates
 */
+blinds_status(Status)[source(Source)] : true <-
    .print("Received blinds status update from ", Source, ": ", Status);
    // Store the current state of the blinds
    -+blinds_state(Status).

/*
 * Plan for handling messages received via Jason's messaging system
 * This plan reacts to lights status updates
 */
+lights_status(Status)[source(Source)] : true <-
    .print("Received lights status update from ", Source, ": ", Status);
    // Store the current state of the lights
    -+lights_state(Status).

/*
 * Plan for wake-up sequence
 * This plan coordinates actions when the owner wakes up
 */
+!wake_up_sequence : true <-
    .print("Executing wake-up sequence");
    // Send messages to other agents to execute their parts of the sequence
    .send(blinds_controller, achieve, raise_blinds);
    .send(lights_controller, achieve, turn_on_lights).

/*
 * Plan for sleep sequence
 * This plan coordinates actions when the owner falls asleep
 */
+!sleep_sequence : true <-
    .print("Executing sleep sequence");
    // Send messages to other agents to execute their parts of the sequence
    .send(blinds_controller, achieve, lower_blinds);
    .send(lights_controller, achieve, turn_off_lights).

/*
 * Plan for alerting the owner about an upcoming event
 */
+!alert_owner_event : true <-
    .print("Alerting owner about upcoming event");
    // In a real implementation, this might flash lights or make sounds
    // For this exercise, we'll just send messages to the devices
    .send(lights_controller, achieve, turn_on_lights).

/* Import behavior of agents that work in CArtAgO environments */
{ include("$jacamoJar/templates/common-cartago.asl") }