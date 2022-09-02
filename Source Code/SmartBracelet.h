/*
	Payload of the messages.
	@author Davide Carini, Riccardo Zanelli
*/

#ifndef SMARTBRACELET_H
#define SMARTBRACELET_H

#define KEY_LENGTH 20 //Length of the KEY

#define COUPLES 4 //In this case we set 4 couples
#define S_MAX 2*COUPLES

#define STANDING 1
#define WALKING 2
#define RUNNING 3
#define FALLING 4

#define REQ 1
#define RESP 2

//Payload of the pairing message
typedef nx_struct pairing_msg {
  nx_uint8_t msg_type; //1->BROADCAST REQ, 2->UNICAST RESP
  nx_uint8_t pairing_key[KEY_LENGTH]; //pre-loaded key of 20 characters
  nx_uint8_t node_id_source; //ID of the node that sends the pairing request
} pairing_msg_t;


//Payload of the child's position
typedef nx_struct position_msg{
  nx_uint8_t x; //X position of the child
  nx_uint8_t y; //Y position of the child
  nx_uint8_t status[12]; //status of the child  (STANDING, WALKING, RUNNING, FALLING)
}position_msg_t;

enum{
	AM_MY_MSG = S_MAX //In our case S_MAX=8
};

#endif
