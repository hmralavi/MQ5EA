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
   10- add stoploss trailing using atr.  ==> DONE
   11- find the channel box based on volume.
   12- find the channel box based on the previous days behavior.
   
*/


#include <../Experts/mq5ea/mytools.mqh>

input group "Time"
input bool use_chart_timeframe = true;
input ENUM_TIMEFRAMES costume_timeframe = PERIOD_M15;
input int market_open_hour = 10;
input int market_open_minute = 0;
input int market_duration_minutes = 60;
input int market_terminate_hour = 21;
input int market_terminate_minute = 0;
input group "Risk"
input double sl_offset_points = 50;  // sl offset points channel edge
input double risk = 2;  // risk %
input double daily_loss_limit = -100;  // daily loss limit ($)
input double Rr = 3;  // reward/risk ratio
input group "Position"
input bool instant_entry = false;
input double second_order_price_ratio = 0.5;  // second order price ratio. 0 close to first order. 1 on the other side of the channel.
input bool close_only_half_size_on_tp = true;
input group "Trailing"
input bool trailing_stoploss = true;
input int atr_period = 100;
input double atr_channel_deviation = 2;
input int Magic = 141;  // EA's magic number

CTrade trade;
string _MO,_MT;
ENUM_TIMEFRAMES tf;
MqlRates ML, MH; // market low, high
bool market_lh_calculated = false;
int atr_handle;
double day_profit;
bool new_candle = false;
bool buy_allowed = true;  // deactivated
bool sell_allowed = true;  // deactivated

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
   if(trailing_stoploss){
      atr_handle = iCustom(_Symbol, tf, "..\\Experts\\mq5ea\\indicators\\atr_channel.ex5", false, atr_period, atr_channel_deviation);
      ChartIndicatorAdd(0, 0, atr_handle);
   }
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason){
   IndicatorRelease(atr_handle);
   ObjectsDeleteAll(0);
}

void OnTick()
{      
   new_candle = IsNewCandle(tf);
   
   if(TimeCurrent() >= MT || TimeCurrent()<MO){
      CloseAllPositions(trade);
      DeleteAllOrders(trade);
      return;
      
   }
   if(TimeCurrent() < MC){
      market_lh_calculated = false;
      day_profit = 0;
      buy_allowed = true;
      sell_allowed = true;
      return;
   }

   if(!market_lh_calculated){
      market_lh_calculated = calculate_market_low_high();
      ObjectsDeleteAll(0);
      ObjectCreate(0, "marketlh", OBJ_RECTANGLE, 0, MC-PeriodSeconds(tf), MH.high, MO, ML.low);    
      ObjectSetInteger(0, "marketlh", OBJPROP_STYLE, STYLE_DOT); 
   }
   
   if(!market_lh_calculated) return;
   
   ulong pos_tickets[], ord_tickets[];
   GetMyPositionsTickets(Magic, pos_tickets);
   GetMyOrdersTickets(Magic, ord_tickets);
   if(trailing_stoploss){
      int npos = ArraySize(pos_tickets);
      for(int ipos=0;ipos<npos;ipos++){
         PositionSelectByTicket(pos_tickets[ipos]);
         ENUM_POSITION_TYPE pos_type = PositionGetInteger(POSITION_TYPE);
         double org_sl = StringToDouble(PositionGetString(POSITION_COMMENT));
         double open_price = PositionGetDouble(POSITION_PRICE_OPEN);      
         double curr_price = PositionGetDouble(POSITION_PRICE_CURRENT);
         double atr[1];
         CopyBuffer(atr_handle, pos_type==POSITION_TYPE_BUY?6:5, 0, 1, atr);  // buffer 5 atrhigh, buffer 6 atrlow
         TrailingStoploss(trade, pos_tickets[ipos], MathAbs(atr[0]-curr_price)/_Point, MathAbs((org_sl-open_price)/_Point));         
      }
   }
   if(ArraySize(pos_tickets) + ArraySize(ord_tickets) > 0) return;  
   
   if(!new_candle) return;
   
   if(day_profit<=daily_loss_limit) return;
   
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   if(iClose(_Symbol,tf,1) > MH.high && buy_allowed){// && iOpen(_Symbol,tf,1) <= MH.high){
      double p1_ = ML.low;
      double p2_ = MH.high;
      double p1 = second_order_price_ratio * (p1_-p2_) + p2_;
      double p2 = instant_entry?ask:p2_;
      double meanp = (p1 + p2)/2;
      double sl = p1_ - sl_offset_points*_Point;
      double tp = p2_ + Rr * (p2_-p1_);
      double lot = calculate_lot_size((meanp-sl)/_Point, risk);
      double lot_ = NormalizeDouble(lot/4, 2);
      double tp2 = close_only_half_size_on_tp?0:tp;
      if(instant_entry){
         trade.Buy(lot_, _Symbol, p2, sl, tp, DoubleToString(sl, _Digits));
         trade.Buy(lot_, _Symbol, p2, sl, tp2, DoubleToString(sl, _Digits));
      }else{
         trade.BuyLimit(lot_, p2, _Symbol, sl, tp, ORDER_TIME_GTC, 0, DoubleToString(sl, _Digits));
         trade.BuyLimit(lot_, p2, _Symbol, sl, tp2, ORDER_TIME_GTC, 0, DoubleToString(sl, _Digits));
      }
      trade.BuyLimit(lot_, p1, _Symbol, sl, tp, ORDER_TIME_GTC, 0, DoubleToString(sl, _Digits));
      trade.BuyLimit(lot_, p1, _Symbol, sl, tp2, ORDER_TIME_GTC, 0, DoubleToString(sl, _Digits));

   }else if(iClose(_Symbol,tf,1) < ML.low && sell_allowed){// && iOpen(_Symbol,tf,1) >= ML.low){
      double p1_ = MH.high;
      double p2_ = ML.low;
      double p1 = second_order_price_ratio * (p1_-p2_) + p2_;
      double p2 = instant_entry?bid:p2_;
      double meanp = (p1 + p2)/2;
      double sl = p1_ + sl_offset_points*_Point;
      double tp = p2_ - Rr * (p1_-p2_);
      double lot = calculate_lot_size((sl-meanp)/_Point, risk);
      double lot_ = NormalizeDouble(lot/4, 2);
      double tp2 = close_only_half_size_on_tp?0:tp;
      if(instant_entry){
         trade.Sell(lot_, _Symbol, p2, sl, tp, DoubleToString(sl, _Digits));
         trade.Sell(lot_, _Symbol, p2, sl, tp2, DoubleToString(sl, _Digits));
      }else{
         trade.SellLimit(lot_, p2, _Symbol, sl, tp, ORDER_TIME_GTC, 0, DoubleToString(sl, _Digits));
         trade.SellLimit(lot_, p2, _Symbol, sl, tp2, ORDER_TIME_GTC, 0, DoubleToString(sl, _Digits));
      }
      trade.SellLimit(lot_, p1, _Symbol, sl, tp, ORDER_TIME_GTC, 0, DoubleToString(sl, _Digits));
      trade.SellLimit(lot_, p1, _Symbol, sl, tp2, ORDER_TIME_GTC, 0, DoubleToString(sl, _Digits));
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
            day_profit += deal.Profit();
            ulong pos_tickets[];
            GetMyPositionsTickets(Magic, pos_tickets);
            int npos = ArraySize(pos_tickets);
            double sl;
            for(int i=0;i<npos;i++){  
               PositionSelectByTicket(pos_tickets[i]);
               sl = PositionGetDouble(POSITION_PRICE_OPEN);                             
               trade.PositionModify(pos_tickets[i], sl, 0); 
            }
            //if(deal.Profit()<0){
            //   if(deal.DealType()==DEAL_TYPE_BUY) sell_allowed=false;
            //   if(deal.DealType()==DEAL_TYPE_SELL) buy_allowed=false;
            //}           
         }
      }
   }   
}

bool calculate_market_low_high(){
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
   return true;
}

double calculate_lot_size(double slpoints, double risk_percent){
   double balance = MathMin(1000,AccountInfoDouble(ACCOUNT_BALANCE));
   double riskusd = risk_percent * balance / 100;
   double lot = riskusd/slpoints;
   lot = NormalizeDouble((MathFloor(lot*100/2)*2)/100,2);
   return lot;
}
