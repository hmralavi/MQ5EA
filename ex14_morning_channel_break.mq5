#include <../Experts/mq5ea/mytools.mqh>

input int market_open_hour = 9;
input int market_open_minute = 0;
input int market_close_hour = 11;
input int market_close_minute = 0;
input bool trade_double_side_break = false;
input double risk = 5;  // risk %
input int nOrders =10;
input int Rr = 2;
input bool riskfree = false;
input int market_terminate_hour = 21;
input int market_terminate_minute = 0;

int Magic = 140;
CTrade trade;
string _MO,_MC,_MT;
bool searching_for_entry = false;
MqlRates ML, MH; // market low, high
bool market_lh_calculated = false;

#define MO StringToTime(_MO)  // market open time
#define MC StringToTime(_MC)  // market close time
#define MT StringToTime(_MT)  // market terminate time


int OnInit()
{
   trade.SetExpertMagicNumber(Magic);
   _MO = IntegerToString(market_open_hour,2,'0')+":"+IntegerToString(market_open_minute,2,'0');
   _MC = IntegerToString(market_close_hour,2,'0')+":"+IntegerToString(market_close_minute,2,'0');
   _MT = IntegerToString(market_terminate_hour,2,'0')+":"+IntegerToString(market_terminate_minute,2,'0');
   return(INIT_SUCCEEDED);
}


void OnTick()
{
   if(!IsNewCandle(_Period)) return;
   
   if(TimeCurrent() >= MT){
      CloseAllPositions(trade);
      DeleteAllOrders(trade);
      return;
      
   }
   if(TimeCurrent()<=MC){
      market_lh_calculated = false;
      return;
   }
   
   ulong pos_tickets[], ord_tickets[];
   GetMyPositionsTickets(Magic, pos_tickets);
   GetMyOrdersTickets(Magic, ord_tickets);
   if(ArraySize(pos_tickets) + ArraySize(ord_tickets) > 0) return;
   
   if(!market_lh_calculated){
      calculate_market_low_high();
      market_lh_calculated = true;
   }
   
   

}

void calculate_market_low_high(){
   MqlRates mrate[];
   ArraySetAsSeries(mrate, true);
   int st = iBarShift(_Symbol, _Period, MC);
   int en = iBarShift(_Symbol, _Period, MO);
   CopyRates(_Symbol,_Period,st,en-st,mrate)<0){
      Alert(__FUNCTION__, "-->Error copying rates/history data - error:",GetLastError(),"!!");
      ResetLastError();
      return;
   }
   MqlRates ml = mrate[0];
   MqlRates mh = mrate[0];
   for(int i=0;i<en-st;i++){
      if(mrate[i].low<ml.low) ml = mrate[i]
      if(mrate[i].high>mh.high) mh = mrate[i]
   }
   ML = ml;
   MH = mh;
}