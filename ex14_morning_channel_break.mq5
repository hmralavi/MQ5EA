#include <../Experts/mq5ea/mytools.mqh>

input int market_open_hour = 9;
input int market_open_minute = 0;
input int market_close_hour = 10;
input int market_close_minute = 0;
input bool trade_double_side_break = false;
input double sl_offset_points = 50;
input double risk = 5;  // risk %
input int nOrders = 2;
input int Rr = 3;
input bool riskfree = false;
input int market_terminate_hour = 23;
input int market_terminate_minute = 0;

int Magic = 140;
CTrade trade;
string _MO,_MC,_MT;
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
   ObjectsDeleteAll(0);
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason){
   ObjectsDeleteAll(0);
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

   if(!market_lh_calculated){
      calculate_market_low_high();
      market_lh_calculated = true;
      ObjectsDeleteAll(0);
      ObjectCreate(0, "marketlh", OBJ_RECTANGLE, 0, MC, MH.high, MO, ML.low);     
   }
   
   ulong pos_tickets[], ord_tickets[];
   GetMyPositionsTickets(Magic, pos_tickets);
   GetMyOrdersTickets(Magic, ord_tickets);
   if(ArraySize(pos_tickets) + ArraySize(ord_tickets) > 0) return;
   
   if((iClose(_Symbol,_Period,1) > MH.high)){
      double p1 = ML.low;
      double p2 = MH.high;
      double meanp = (p1 + p2)/2;
      double sl = p1 - sl_offset_points*_Point;
      double tp = p2 + Rr * (p2-p1);
      double lot = calculate_lot_size((meanp-sl)/_Point, risk);
      double p;
      double lot_ = NormalizeDouble(lot/nOrders, 2);
      for(int i=0;i<nOrders;i++){
         p = i*(p2-p1)/(nOrders-1) + p1;
         p = NormalizeDouble(p, _Digits);
         trade.BuyLimit(lot_, p, _Symbol, sl, tp);
      }      
   }else if((iClose(_Symbol,_Period,1) < ML.low)){
      double p1 = MH.high;
      double p2 = ML.low;
      double meanp = (p1 + p2)/2;
      double sl = p1 + sl_offset_points*_Point;
      double tp = p2 - Rr * (p1-p2);
      double lot = calculate_lot_size((sl-meanp)/_Point, risk);
      double p;
      double lot_ = NormalizeDouble(lot/nOrders, 2);
      for(int i=0;i<nOrders;i++){
         p = i*(p2-p1)/(nOrders-1) + p1;
         p = NormalizeDouble(p, _Digits);
         trade.SellLimit(lot_, p, _Symbol, sl, tp);
      }      
   }
}

void calculate_market_low_high(){
   MqlRates mrate[];
   ArraySetAsSeries(mrate, true);
   int st = iBarShift(_Symbol, _Period, MC);
   int en = iBarShift(_Symbol, _Period, MO);
   CopyRates(_Symbol,_Period,st,en-st+1,mrate);
   MqlRates ml = mrate[0];
   MqlRates mh = mrate[0];
   for(int i=0;i<en-st+1;i++){
      if(mrate[i].low<ml.low) ml = mrate[i];
      if(mrate[i].high>mh.high) mh = mrate[i];
   }
   ML = ml;
   MH = mh;
}