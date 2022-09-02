#include "SmartBracelet.h"

configuration SmartBraceletAppC {}
implementation {
  components MainC,RandomC, SmartBraceletC as App;
  components new TimerMilliC() as MilliTimerBroadcastPairing;
  components new TimerMilliC() as MilliTimer10sec;
  components new TimerMilliC() as MilliTimer60sec;
  
  components new AMSenderC(AM_MY_MSG);
  components new AMReceiverC(AM_MY_MSG);
  components ActiveMessageC;
  
  //Random interface
  RandomC <- MainC.SoftwareInit;
  App.Random -> RandomC;
  
  //Boot interface
  App.Boot -> MainC.Boot;
  
  //Timer interface
  App.MilliTimerBroadcastPairing -> MilliTimerBroadcastPairing;
  App.MilliTimer10sec -> MilliTimer10sec;
  App.MilliTimer60sec -> MilliTimer60sec;
  
  //Send and Receive interface
  App.Receive -> AMReceiverC;
  App.AMSend -> AMSenderC;
  App.Packet -> AMSenderC;
  App.SplitControl -> ActiveMessageC;
  App.Ack -> ActiveMessageC;
}


