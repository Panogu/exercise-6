// wristband manager agent

/* Initial beliefs */
// The agent has a belief about the location of the W3C Web of Thing (WoT) Thing Description (TD)
// that describes a Thing of type https://was-course.interactions.ics.unisg.ch/wake-up-ontology#Wristband (was:Wristband)
td("https://was-course.interactions.ics.unisg.ch/wake-up-ontology#Wristband", "https://raw.githubusercontent.com/Interactions-HSG/example-tds/was/tds/wristband-simu.ttl").

// The agent has an empty belief about the state of the wristband's owner
owner_state(_).

/* Initial goals */
// The agent has the goal to start
!start.

/*
 * Plan for reacting to the addition of the goal !start
 * Triggering event: addition of goal !start
 * Context: the agents believes that a WoT TD of a was:Wristband is located at Url
 * Body: the agent creates a ThingArtifact using the WoT TD of a was:Wristband and creates the goal to read the owner's state
*/
@start_plan
+!start : td("https://was-course.interactions.ics.unisg.ch/wake-up-ontology#Wristband", Url) <-
    .print("Wristband Manager starting up...");
    
    // Create a ThingArtifact for the wristband
    makeArtifact("wristband", "org.hyperagents.jacamo.artifacts.wot.ThingArtifact", [Url], ArtId);
    focus(ArtId);
    
    // Create an MQTT artifact for communication
    .my_name(Name);
    .concat("mqtt_", Name, ArtifactName);
    makeArtifact(ArtifactName, "room.MQTTArtifact", [Name], MqttId);
    focus(MqttId);
    .print("Connected to MQTT broker as ", Name);
    
    !read_owner_state. // creates the goal !read_owner_state

// Failure handling plan for MQTT artifact creation
-!start[error(action_failed), error_msg(Msg), env_failure_reason(makeArtifactFailure("artifact_already_present", ArtName))] : 
    td("https://was-course.interactions.ics.unisg.ch/wake-up-ontology#Wristband", Url) <-
    .print("MQTT Artifact ", ArtName, " already exists. Focusing on existing artifact.");
    lookupArtifact(ArtName, ArtId);
    focus(ArtId);
    .print("Connected to existing MQTT broker");
    
    // Create a ThingArtifact for the wristband
    makeArtifact("wristband", "org.hyperagents.jacamo.artifacts.wot.ThingArtifact", [Url], WristId);
    focus(WristId);
    
    !read_owner_state.

/*
 * Plan for reacting to the addition of the goal !read_owner_state
 * Triggering event: addition of goal !read_owner_state
 * Context: true (the plan is always applicable)
 * Body: every 5000ms, the agent exploits the TD Property Affordance of type was:ReadOwnerState to perceive the owner's state
 *       and updates its belief owner_state accordingly
*/
@read_owner_state_plan
+!read_owner_state : true <-
    // performs an action that exploits the TD Property Affordance of type was:ReadOwnerState
    // the action unifies OwnerStateLst with a list holding the owner's state, e.g. ["asleep"]
    readProperty("https://was-course.interactions.ics.unisg.ch/wake-up-ontology#ReadOwnerState", OwnerStateLst);
    .nth(0, OwnerStateLst, OwnerState); // performs an action that unifies OwnerState with the element of the list OwnerStateLst at index 0
    -+owner_state(OwnerState); // updates the belief owner_state
    .wait(5000);
    !read_owner_state. // creates the goal !read_owner_state

/*
 * Plan for reacting to the addition of the belief !owner_state
 * Triggering event: addition of belief !owner_state
 * Context: true (the plan is always applicable)
 * Body: announces the current state of the owner and informs the personal assistant
*/
@owner_state_plan
+owner_state(State) : true <-
    .print("The owner is ", State);
    
    // Inform the personal assistant about the state change using KQML performative "inform"
    .send(personal_assistant, tell, owner_state(State)).
    
    // Send message via MQTT
    // sendMsg("personal_assistant", "inform", "owner_state(State)").

/* Import behavior of agents that work in CArtAgO environments */
{ include("$jacamoJar/templates/common-cartago.asl") }