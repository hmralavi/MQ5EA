/*
ex14_morning_channel_break EA

TODO:
   1- dont place the limit orders exactly on channel edges. consider broker spread. ==> DONE
   2- set nOrders constant and equal to 2. ==> DONE
   3- each limit order should be devided to two orders with half lot size. one order with tp and one without tp. both should have sl.  ==> DONE
   4- sl must be placed on the last swing below or above the channel.  !!!!! this needs to be done in the future!!!!!!!!!
   6- when tp or sl triggers, delete all pending orders and move current positions sl to the channel edge (consider spread).  ==> DONE
   7- if stoploss happens, delete all pending orders.  ==> DONE
   8- place one order on the edge. place the other order with a ratio between two edges of the channel. useful for fibunacci  levels entry.  ==> DONE
   9- market close time input as number of bars starting from market open  ==> DONE
   10- add stoploss trailing using atr.
*/

#include <../Experts/mq5ea/mytools.mqh>

input bool use_chart_timeframe = true;
input ENUM_TIMEFRAMES costume_timeframe = PERIOD_M15;
input int market_open_hour = 9;
input int market_open_minute = 0;
input int market_duration_minutes = 60;
input int market_terminate_hour = 23;
input int market_terminate_minute = 0;
input double sl_offset_points = 50;  // sl offset points channel edge
input double risk = 5;  // risk %
input double Rr = 3;  // reward/risk ratio
input double broker_spread_points = 13;
input bool instant_entry = false;
input double second_order_price_ratio = 0.5;  // second order price ratio. 0 close to first order. 1 on the other side of the channel.
input bool close_only_half_size_on_tp = false;
input int Magic = 141;  // EA's magic number

CTrade trade;
string _MO,_MT;
ENUM_TIMEFRAMES tf;
MqlRates ML, MH; // market low, high
bool market_lh_calculated = false;

#define MO StringToTime(_MO)  // market open time
#define MC MO + market_duration_minutes*60  // market close time
#define MT StringToTime(_MT)  // market terminate time

int OnInit()
{
   trade.SetExpertMagicNumber(Magic);
   _MO = IntegerToString(market_open_hour,2,'0')+":"+IntegerToString(market_open_minute,2,'0');
   _MT = IntegerToString(market_terminate_hour,2,'0')+":"+IntegerToString(market_terminate_minute,2,'0');
   if(use_chart_timeframe) tf = _Period;
   else tf = costume_timeframe;
   ObjectsDeleteAll(0);
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason){
   ObjectsDeleteAll(0);
}

void OnTick()
{   
   if(TimeCurrent() >= MT){
      CloseAllPositions(trade);
      DeleteAllOrders(trade);
      return;
      
   }
   if(TimeCurrent() < MC){
      market_lh_calculated = false;
      return;
   }

   if(!market_lh_calculated){
      calculate_market_low_high();
      market_lh_calculated = true;
      ObjectsDeleteAll(0);
      ObjectCreate(0, "marketlh", OBJ_RECTANGLE, 0, MC-PeriodSeconds(tf), MH.high, MO, ML.low);    
      ObjectSetInteger(0, "marketlh", OBJPROP_STYLE, STYLE_DOT); 
   }
   
   if(!IsNewCandle(tf)) return;
   
   ulong pos_tickets[], ord_tickets[];
   GetMyPositionsTickets(Magic, pos_tickets);
   GetMyOrdersTickets(Magic, ord_tickets);
   if(ArraySize(pos_tickets) + ArraySize(ord_tickets) > 0) return;   
   
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   if((iClose(_Symbol,tf,1) > MH.high && iOpen(_Symbol,tf,1) <= MH.high)){
      double p1_ = ML.low + broker_spread_points*_Point;
      double p2_ = MH.high + broker_spread_points*_Point;
      double p1 = second_order_price_ratio * (p1_-p2_) + p2_;
      double p2 = instant_entry?ask:p2_;
      double meanp = (p1 + p2)/2;
      double sl = p1_ - sl_offset_points*_Point;
      double tp = p2_ + Rr * (p2_-p1_);
      double lot = calculate_lot_size((meanp-sl)/_Point, risk);
      double lot_ = NormalizeDouble(lot/4, 2);
      double tp2 = close_only_half_size_on_tp?0:tp;
      if(instant_entry){
         trade.Buy(lot_, _Symbol, p2, sl, tp);
         trade.Buy(lot_, _Symbol, p2, sl, tp2);
      }else{
         trade.BuyLimit(lot_, p2, _Symbol, sl,tp);
         trade.BuyLimit(lot_, p2, _Symbol, sl,tp2);
      }
      trade.BuyLimit(lot_, p1, _Symbol, sl,tp);
      trade.BuyLimit(lot_, p1, _Symbol, sl,tp2);

   }else if((iClose(_Symbol,tf,1) < ML.low && iOpen(_Symbol,tf,1) >= ML.low)){
      double p1_ = MH.high + broker_spread_points*_Point;
      double p2_ = ML.low + broker_spread_points*_Point;
      double p1 = second_order_price_ratio * (p1_-p2_) + p2_;
      double p2 = instant_entry?bid:p2_;
      double meanp = (p1 + p2)/2;
      double sl = p1_ + sl_offset_points*_Point;
      double tp = p2_ - Rr * (p1_-p2_);
      double lot = calculate_lot_size((sl-meanp)/_Point, risk);
      double lot_ = NormalizeDouble(lot/4, 2);
      double tp2 = close_only_half_size_on_tp?0:tp;
      if(instant_entry){
         trade.Sell(lot_, _Symbol, p2, sl, tp);
         trade.Sell(lot_, _Symbol, p2, sl, tp2);
      }else{
         trade.SellLimit(lot_, p2, _Symbol, sl,tp);
         trade.SellLimit(lot_, p2, _Symbol, sl,tp2);
      }
      trade.SellLimit(lot_, p1, _Symbol, sl,tp);
      trade.SellLimit(lot_, p1, _Symbol, sl,tp2);
   }
}

void OnTradeTransaction(const MqlTradeTransaction& trans,
                        const MqlTradeRequest& request,
                        const MqlTradeResult& result)
{   
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD){
      CDealInfo deal;
      deal.Ticket(trans.deal);
      HistorySelect(TimeCurrent()-PeriodSeconds(PERIOD_D1), TimeCurrent()+10);
      if(deal.Magic()==Magic && deal.Symbol()==_Symbol){
         if(deal.Entry()==DEAL_ENTRY_OUT){
            DeleteAllOrders(trade);
            ulong pos_tickets[];
            GetMyPositionsTickets(Magic, pos_tickets);
            int npos = ArraySize(pos_tickets);
            double sl;
            if(iClose(_Symbol,tf,0)>=MH.high) sl=MH.high;
            if(iClose(_Symbol,tf,0)<=ML.low) sl=ML.low;
            for(int i=0;i<npos;i++){              
               trade.PositionModify(pos_tickets[i], sl, 0); 
            }           
         }
      }
   }   
}

void calculate_market_low_high(){
   MqlRates mrate[];
   ArraySetAsSeries(mrate, true);
   int st = iBarShift(_Symbol, tf, MC)+1;
   int en = iBarShift(_Symbol, tf, MO);
   CopyRates(_Symbol,tf,st,en-st+1,mrate);
   MqlRates ml = mrate[0];
   MqlRates mh = mrate[0];
   for(int i=0;i<en-st+1;i++){
      if(mrate[i].low<ml.low) ml = mrate[i];
      if(mrate[i].high>mh.high) mh = mrate[i];
   }
   ML = ml;
   MH = mh;
}

double calculate_lot_size(double slpoints, double risk_percent){
   double balance = MathMin(1000,AccountInfoDouble(ACCOUNT_BALANCE));
   double riskusd = risk_percent * balance / 100;
   double lot = riskusd/slpoints;
   lot = NormalizeDouble((MathFloor(lot*100/2)*2)/100,2);
   return lot;
}
