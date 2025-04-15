package room;

import cartago.Artifact;
import cartago.INTERNAL_OPERATION;
import cartago.OPERATION;
import org.eclipse.paho.client.mqttv3.*;

/**
 * A CArtAgO artifact that provides an operation for sending messages to agents 
 * with KQML performatives using the dweet.io API
 */
public class MQTTArtifact extends Artifact {

    MqttClient client;
    String broker = "tcp://test.mosquitto.org:1883";
    String clientId;
    String topic = "was-exercise-6/communication-adrian";
    int qos = 2;

    public void init(String name){
        // Subscribe to the MQTT broker and add observable properties for perceived messages
        //The name is used for the clientId.
        clientId = name;

        try {
            // Create a new MQTT client
            client = new MqttClient(broker, clientId);
            
            // Set callback for handling received messages
            client.setCallback(new MQTTCallback(this));
            
            // Connect to the broker
            MqttConnectOptions connOpts = new MqttConnectOptions();
            connOpts.setCleanSession(true);
            client.connect(connOpts);
            
            // Subscribe to the topic
            client.subscribe(topic);
            
            // Define observable property to store messages - not explicitly required in the task but useful for tracking
            defineObsProperty("messages_count", 0);
            
            System.out.println("MQTT Artifact initialized. Connected to broker: " + broker);
            System.out.println("Subscribed to topic: " + topic);
        } catch (MqttException e) {
            failed("Error initializing MQTT connection: " + e.getMessage());
        }
    }

    @OPERATION
    public void sendMsg(String agent, String performative, String content){
        try {

            // Throw an error if any of agent, performative or content contain a comma
            if(agent.contains(",") || performative.contains(",") || content.contains(",")){
                failed("Error: agent, performative and content cannot contain a comma (,)");
                return;
            }

            // Create the message as a string in the format "agent,performative,content"
            String message = agent + "," + performative + "," + content;
            
            // Create an MQTT message
            MqttMessage mqttMessage = new MqttMessage(message.getBytes());
            mqttMessage.setQos(qos);
            
            // Publish the message
            client.publish(topic, mqttMessage);
            
            System.out.println("Message sent - Topic: " + topic + " Message: " + message);
        } catch (MqttException e) {
            failed("Error sending MQTT message: " + e.getMessage());
        }
    }

    @INTERNAL_OPERATION
    public void addMessage(String agent, String performative, String content){
        // Add a new observable property for the received message - not explicitly required in the task but useful for tracking
        int count = getObsProperty("messages_count").intValue();
        
        // Define a new observable property with the message details
        defineObsProperty("message", agent, performative, content);
        
        // Update the message counter
        getObsProperty("messages_count").updateValue(count + 1);
        
        System.out.println("New message added: " + agent + " - " + performative + " - " + content);
    }
    
    // Custom callback class to process received messages
    private class MQTTCallback implements MqttCallback {
        private MQTTArtifact artifact;
        
        public MQTTCallback(MQTTArtifact artifact) {
            this.artifact = artifact;
        }
        
        @Override
        public void connectionLost(Throwable cause) {
            System.out.println("Connection to MQTT broker lost: " + cause.getMessage());
            // Attempt to reconnect
            try {
                client.connect();
                client.subscribe(topic);
            } catch (MqttException e) {
                System.err.println("Failed to reconnect: " + e.getMessage());
            }
        }
        
        @Override
        public void messageArrived(String topic, MqttMessage message) throws Exception {
            String messageContent = new String(message.getPayload());
            System.out.println("Message received (" + clientId + "): " + messageContent);
            
            // Parse the message content (agent,performative,content)
            String[] parts = messageContent.split(",");
            if (parts.length != 3) {
                System.err.println("Invalid message format. Expected: agent,performative,content");
                return;
            }
            
            // Add the message as an observable property
            artifact.execInternalOp("addMessage", parts[0].trim(), parts[1].trim(), parts[2].trim());
        }
        
        @Override
        public void deliveryComplete(IMqttDeliveryToken token) {
            // Optional: Handle delivery confirmation
            System.out.println("Message delivery confirmed");
        }
    }
    
}
