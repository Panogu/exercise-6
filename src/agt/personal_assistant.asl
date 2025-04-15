// personal assistant agent

/* Initial beliefs */
broadcast(mqtt).
wakeup_in_progress(false).  // New belief to track wake-up status

// Wake-up method preferences (lower rank = more preferred)
wakeup_method("natural_light", 0).  // Natural light (lowest rank = most preferred)
wakeup_method("artificial_light", 1). // Artificial light

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
 * Plan for handling messages received via Jason's messaging system
 * This plan reacts to owner state changes from the wristband manager
 */
+owner_state(State)[source(Source)] : true <-
    .print("Received owner state update from ", Source, ": ", State);
    
    // Check if there's a pending event that requires waking up the owner
    if (current_event("now") & State == "asleep" & not wakeup_in_progress(true)) {
        .print("Owner is asleep but has an event now. Starting wake-up routine...");
        !initiate_wakeup;
    } elif (current_event("now") & State == "awake") {
        -+wakeup_in_progress(false);  // Reset wake-up status when owner wakes up
        .print("Enjoy your event!");
    }.

/*
 * Plan for handling messages received via Jason's messaging system
 * This plan reacts to upcoming calendar events
 */
+upcoming_event(Event)[source(Source)] : true <-
    .print("Received calendar event update from ", Source, ": ", Event);
    // Store the current event state
    -+current_event(Event);
    
    // If event is happening now, check if owner needs to be awakened
    if (Event == "now") {
        !check_wakeup_need;
    }.

/*
 * Plan to check if the owner needs to be woken up
 */
+!check_wakeup_need : owner_state("awake") & current_event("now") <-
    .print("Enjoy your event!").
    
+!check_wakeup_need : owner_state("asleep") & current_event("now") & not wakeup_in_progress(true) <-
    .print("Starting wake-up routine...");
    !initiate_wakeup.

+!check_wakeup_need : owner_state("asleep") & current_event("now") & wakeup_in_progress(true) <-
    .print("Wake-up routine already in progress. Not starting another one.").

// If we don't have info on owner state yet
+!check_wakeup_need : not owner_state(_) & current_event("now") & not wakeup_in_progress(true) <-
    .print("Event is now but owner state is unknown. Waiting for wristband data...");
    .wait(1000);  // Wait a bit and try again
    !check_wakeup_need.
    
// If a wake-up is already in progress, don't keep checking
+!check_wakeup_need : not owner_state(_) & current_event("now") & wakeup_in_progress(true) <-
    .print("Wake-up routine already initiated. Waiting for completion...").

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
 * Plan for initiating the wake-up sequence using the Contract Net Protocol
 * This selects the best method to wake up the user based on preferences
 */
+!initiate_wakeup : broadcast(jason) <-
    -+wakeup_in_progress(true);  // Set wake-up status to in progress
    .print("Broadcasting CFP via Jason for increasing illuminance in the room");
    .broadcast(achieve, cfp(task("increase_illuminance")));
    // Wait for proposals to come in
    .wait(1000);
    !evaluate_proposals.

+!initiate_wakeup : not broadcast(jason) <-
    -+wakeup_in_progress(true);  // Set wake-up status to in progress
    .wait(3000);
    .print("Broadcasting CFP via MQTT for increasing illuminance in the room");
    sendMsg("personal_assistant", "tell", "cfp(increase_illuminance)");
    // Wait for proposals to come in (longer because MQTT might take longer)
    .wait(3000);
    !evaluate_proposals.

/*
 * Plan for evaluating proposals for increasing illuminance
 */
+!evaluate_proposals : true <-
    .findall(proposal(Agent, Method, Rank), 
             (proposal(Method)[source(Agent)] & wakeup_method(Method, Rank)),
             Proposals);
    
    .print("Received proposals: ", Proposals);
    
    // Check if we have any proposals
    if (.empty(Proposals)) {
        .print("No proposals received. Cannot proceed with regular wake-up routine.");
        -+wakeup_in_progress(false);  // Reset wake-up status if failed

        // Send MQTT message to the user's friend
        !send_mqtt("personal_assistant", "request_friend", "No proposals received for wake-up routine. Please wake up the user.");

    } else {
        // Sort proposals by rank (ascending)
        .sort(Proposals, SortedProposals);
        .print("Sorted proposals: ", SortedProposals);
        
        // Accept the best proposal (first in sorted list) and reject others
        !handle_sorted_proposals(SortedProposals);
    }.

/*
 * Plan for handling sorted proposals
 * Accepts the first (best) proposal and rejects all others
 */
+!handle_sorted_proposals([proposal(BestAgent, BestMethod, _)|RestProposals]) : true <-
    .print("Accepting proposal from ", BestAgent, " to increase illuminance using ", BestMethod);
    .send(BestAgent, tell, accept_proposal(task("increase_illuminance")));
    
    // Clear any existing proposals to prevent duplicates
    .abolish(proposal(_)[source(_)]);
    
    // Reject all other proposals
    !reject_other_proposals(RestProposals).

// Base case for rejecting proposals - no more to reject
+!reject_other_proposals([]) : true <- true.

// Recursive case for rejecting proposals
+!reject_other_proposals([proposal(Agent, Method, _)|Rest]) : true <-
    .print("Rejecting proposal from ", Agent, " to increase illuminance using ", Method);
    .send(Agent, tell, reject_proposal(task("increase_illuminance")));
    !reject_other_proposals(Rest).

/*
 * Plans for handling task completion reports (specified in FIPA)
 */
+inform_done(Task, Method)[source(Source)] : owner_state("asleep") & wakeup_in_progress(true) <-
    .print("Task ", Task, " completed by ", Source, " using method: ", Method);
    .print("User still asleep. Starting a new call for proposals...");
    
    // Start a new CFP
    !initiate_wakeup.


+inform_done(Task, Method)[source(Source)] : owner_state("awake") <-
    .print("Task ", Task, " completed by ", Source, " using method: ", Method);
    .print("User has woken up. Wake-up routine successful!");
    -+wakeup_in_progress(false).  // Reset wake-up status on success

/*
 * Plan for handling refuse messages
 */
+refuse(Task, Reason)[source(Source)] : true <-
    .print("Agent ", Source, " refused task ", Task, ". Reason: ", Reason).

/*
 * Plan for handling proposal messages received via Jason's messaging system
 */
+proposal(Method)[source(Source)] : wakeup_in_progress(true) <-
    .print("Received proposal from ", Source, " to increase illuminance using ", Method).
    
+proposal(Method)[source(Source)] : not wakeup_in_progress(true) <-
    .print("Received proposal from ", Source, " but no wake-up routine is active. Ignoring.").

/* Import behavior of agents that work in CArtAgO environments */
{ include("$jacamoJar/templates/common-cartago.asl") }