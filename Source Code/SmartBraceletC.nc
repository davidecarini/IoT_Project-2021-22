/**
	Smart Bracelets Project 2021/2022.
	@author Davide Carini, Riccardo Zanelli
 */

//Imports the libraries
#include "Timer.h"
#include "SmartBracelet.h"


module SmartBraceletC @safe() {
  uses {
    /****** INTERFACES *****/
    interface Boot;
    
    //interfaces for communication
    interface Receive;
    interface AMSend;
    interface Packet;
    interface SplitControl;
    interface Random;
    
    //interface for ACK packets  
    interface PacketAcknowledgements as Ack;
    
    //interface for timers
    interface Timer<TMilli> as MilliTimerBroadcastPairing;
    interface Timer<TMilli> as MilliTimer10sec;
    interface Timer<TMilli> as MilliTimer60sec;
  }
}
implementation {
  
  //********************************************Local Variables***********************************************//
  message_t packet; 
  
  uint8_t paired_device=0; //ID of the paired bracelet (Initially set to 0-> no bracelet associated)
  uint8_t role;  //0-> parent, 1-> child
  
  uint8_t KEY[KEY_LENGTH]; //pre-loaded key of 20 chars
  
  
  uint8_t bracelet_phase=0; //0-> OFF, 1-> Pairing phase, 2-> Operation phase (Initially the bracelet is OFF)
  
  uint8_t lastPosition_x=0; //Last X Position received from the parent 
  uint8_t lastPosition_y=0; //Last Y Position received from the parent 
  
  uint8_t counter=0;
  
  uint8_t same_key_device;
  bool locked =FALSE;
  //************************************************************************************************************//
  
  //sendPairingReq : This function is called when the parents and childs want to send a pairing request in BROADCAST.
  void sendPairingReq() {
  	  int i;
  	  if(!locked){
		  pairing_msg_t* rcm = (pairing_msg_t*)call Packet.getPayload(&packet, sizeof(pairing_msg_t));
		  
		  //Prepare the message
		  dbg("radio_send", "Creating the pairing message...\n");   
		  rcm->msg_type=REQ;    
		  for (i=0; i<KEY_LENGTH; i++){
			rcm->pairing_key[i]= KEY[i]; 
		  } 
		  rcm->node_id_source = TOS_NODE_ID;
		 
		  dbg("radio_send", "Sending the pairing message with source ID:%d \n",TOS_NODE_ID);
		  
		  //Send a BROADCAST message in the network
		  if (call AMSend.send(AM_BROADCAST_ADDR, &packet, sizeof(pairing_msg_t))==SUCCESS){
		  	locked = TRUE;        
		  }
      }
    }
    
    //Send sendSpecialMsg function
  	void sendPairingResp() {
 	 if (!locked) {
	  pairing_msg_t* rcm = (pairing_msg_t*)call Packet.getPayload(&packet, sizeof(pairing_msg_t));
	   
      //Prepare the msg
      dbg("radio_send", "%d creates the special message to stop pairing phase...\n", TOS_NODE_ID);
        
      //Set the ACK flag for the message using the PacketAcknowledgements interface
	  call Ack.requestAck(&packet);
	  rcm->msg_type=RESP;
      rcm->node_id_source = TOS_NODE_ID; 
     //Send an unicast message to the other device with the same KEY
      if (call AMSend.send(same_key_device, &packet, sizeof(pairing_msg_t))==SUCCESS){
    	   	locked = TRUE;
		    dbg("radio_pack","Special message of node %d sent!\n", TOS_NODE_ID);
      }
    }
  }
  
    
    
    //sendPosition : This function is called by the childs to send the position to the parent every 10 seconds.
    void sendPosition() {
      int random;
      if(!locked){
		  position_msg_t* positionMsg = (position_msg_t*)call Packet.getPayload(&packet, sizeof(position_msg_t));
		  
		  //Prepare the message
		  dbg("radio_send", "%d creates the position message...\n", TOS_NODE_ID);
		  
		  positionMsg->x= call Random.rand16();
		  positionMsg->y= call Random.rand16();
		  random = call Random.rand16() % 10;
		  
		  dbg("radio_send", "Generated status %d \n",random);
		  if(random<3)
		  	strcpy(positionMsg->status,"STANDING");
		  else if(random<6)
		  	strcpy(positionMsg->status,"WALKING");
		  else if(random<9)
		  	strcpy(positionMsg->status,"RUNNING");
		  else
		  	strcpy(positionMsg->status,"FALLING");
		  
		  dbg("radio_send", "%d send status %s \n",TOS_NODE_ID,positionMsg->status);
		  dbg("radio_send", "Sending the position message: (%d,%d)\t",positionMsg->x,positionMsg->y);
		
		 //Set the ACK flag for the message using the PacketAcknowledgements interface
		  call Ack.requestAck(&packet);
		  
		 //Send the message in UNICAST to the paired device
		  if (call AMSend.send(paired_device, &packet, sizeof(position_msg_t))==SUCCESS){
		  	locked = TRUE;
		    dbg_clear("radio_pack", "Status:%s\n",positionMsg->status);
		  }
      }
    }
        

  // EVENT: Boot
  event void Boot.booted() {
  	int i;
    dbg("boot","Application booted on bracelet %u\n", TOS_NODE_ID);
    for (i=0; i<KEY_LENGTH; i++){
		KEY[i]= (TOS_NODE_ID-1)/2; //The 1 and 2 nodes have KEY=000000000000000000, the 3 and 4 nodes have KEY=11111111111111111, etc...
	}
	role= (TOS_NODE_ID+1)%2; //The parent has role 0 while the child has role 1.
    call SplitControl.start();
  }
  
  
  //***************** SplitControl interface ********************//
  // EVENT : StartDone
  event void SplitControl.startDone(error_t err){
    if (err == SUCCESS) {
      dbg("radio", "Bracelet %d successfully started!\n",TOS_NODE_ID);
      //bracelet_phase++; //Move from OFF(0) to PAIRING phase (1)
      dbg("radio", "Bracelet %u in Pairing phase\n", TOS_NODE_ID);
      call MilliTimerBroadcastPairing.startPeriodic(400); //Start the timer for sending PAIRING messages
    }
    else {
      dbgerror("radio", "Bracelet failed to start, retrying...\n");
      call SplitControl.start();
    }
  }
  

  // EVENT : MilliTimerBroadcastPairing Fired. This timer calls the function sendPairingReq every 400 ms until the device finds another device with the same pairing KEY
  event void MilliTimerBroadcastPairing.fired() {   
  	dbg("timer","MilliTimerBroadcastPairing Fired.\n");
  	if(paired_device==0){
		sendPairingReq();
	}
	else
		call MilliTimerBroadcastPairing.stop(); // It means that the bracelet has found the device to which connect
  }
  
  
   // EVENT : MilliTimer10sec Fired
  event void MilliTimer10sec.fired() {   
  	dbg("timer","MilliTimer10sec Fired.\n");	
 	sendPosition();
  }
  
    // EVENT : MilliTimer60sec Fired
  event void MilliTimer60sec.fired() {   
  	dbg("timer","MilliTimer60sec Fired.\n");	
 	dbg("timer","***************************MISSING ALARM*************************\n");	
 	dbg("radio_rec", "Last Position of the child detected: (%d,%d)\n",lastPosition_x,lastPosition_y);
  }
 
 
  // EVENT : StopDone
  event void SplitControl.stopDone(error_t err){
      dbg("role", "Shutting down the mote %d... \n", TOS_NODE_ID);
	  dbg("role", "Done! \n");
  }


   //********************* AMSend interface ****************//
  event void AMSend.sendDone(message_t* buf,error_t err) {
	// Check if the packet is sent
	 if (&packet == buf) {
	     //dbg("radio_send", "Packet sent...\n");
	     locked = FALSE;
     }
     else{
    	 dbg("radio_send", "Error in sending pairing packet...");
     }
     
      //Check if the ACK is received
	 if(call Ack.wasAcked(&packet) &&bracelet_phase==1){
	 	dbg_clear("radio_ack", "\tACK message received at time %s\n", sim_time_string());
	 	bracelet_phase++;
  	 }
  	  else if(bracelet_phase==1 && call Ack.wasAcked(&packet)==SUCCESS){
       dbgerror("radio_ack", "Ack not received!\n");
       sendPairingResp();
     }
     
     if(call Ack.wasAcked(&packet) &&bracelet_phase ==2){
	 	dbg_clear("radio_ack", "\tACK position message received by node %d\n",TOS_NODE_ID);
  	 }
  	  else if(bracelet_phase==2){
       dbgerror("radio_ack", "Ack position message not received!\n");
       sendPosition();
     }

  	 	
  }

  
  //***************************** Receive interface *****************//
  event message_t* Receive.receive(message_t* buf,void* payload, uint8_t len) {
	 pairing_msg_t* pairingMsg;
	 position_msg_t* positionMsg;

	 int i;
	 bool same_key=TRUE; 
	 
		 if (len != sizeof(pairing_msg_t) && len != sizeof(position_msg_t)) {
		 	//dbgerror("radio", "Packet malformed\n");
		 	return buf;
		 }
		 else if (len == sizeof(pairing_msg_t) ){
			 pairingMsg = (pairing_msg_t*)payload;
			 
			 if(pairingMsg->msg_type==1){
				 dbg("radio_rec", "Device %d receives broadcast message from: %d\n",TOS_NODE_ID, pairingMsg->node_id_source);
				 counter++;
				 if((pairingMsg->node_id_source%2)!=(TOS_NODE_ID%2)) //Check if one is a parent and the other is a child 
				 {
				 	 //Check if the 2 KEYS coincide
					 for(i=0;i<KEY_LENGTH;i++){ 
					 	if(pairingMsg->pairing_key[i]!=KEY[i]){
					 		same_key=FALSE;
					 		dbg("radio_rec", "Rejected Broadcast message because of different key...\n");
					 		break;
					 	}
					 }
				 }
				 else{
				 	dbg("radio_rec", "Rejected Broadcast message\n");
				 	same_key=FALSE;
				 }
				
				 if (same_key) {
				 	same_key_device=pairingMsg->node_id_source;
					dbg("radio_rec", "The broadcast message received has the same pre-loaded key...\n");		
					
					bracelet_phase++;
					sendPairingResp(); //Send the special message for stop the pairing mode
				}
			}
		
			else{
		 		//Save address of other device 
				paired_device = pairingMsg->node_id_source;
				dbg("radio_rec", "Associated device %d with %d\n",TOS_NODE_ID,pairingMsg->node_id_source);
				  //From PAIRING phase to OPERATION phase
				//If it's the PARENT starts the 1 minute timer 
				if(role==0){
					call MilliTimer60sec.startOneShot(60000); 
				}
			
				//If it's the CHILD starts the 10 seconds timer 
				else if(role==1){
					dbg("radio_rec", "%d starts the Timer10sec\n", TOS_NODE_ID);
					call MilliTimer10sec.startPeriodic(10000);
				}
			
	    	 }
	    	 
	   } 
		 
  		else if(len == sizeof(position_msg_t) && bracelet_phase==2){
	    	if(role==0){
			 	call MilliTimer60sec.stop();
				positionMsg = (position_msg_t*)payload;
			
			 	dbg("radio", "Status received (%s)\n",positionMsg->status);
			 	lastPosition_x = positionMsg->x;
			 	lastPosition_y = positionMsg->y;
			 	call MilliTimer60sec.startOneShot(60000);
			 	
			 	if(strcmp(positionMsg->status,"FALLING")==0){
			 		dbg("radio_rec", "FALL ALARM!!!.\n");
			 		dbg("radio_rec", "Position: (%d,%d)\n",positionMsg->x,positionMsg->y);
			 	}
			}		
  		}
  	return buf;
 }
 }
