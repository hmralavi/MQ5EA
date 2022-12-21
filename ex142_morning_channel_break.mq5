/*
ex14_morning_channel_break EA

similar to ex141
differences: 
1-the orders/positions only get place at one single price
2-daily loss limit removed
3-breaking candle's open must be inside the box

   
*/


#include <../Experts/mq5ea/mytools.mqh>


enum ENUM_EXIT_POLICY{
   EXIT_POLICY_BREAKEVEN = 0,  // Breakeven if in loss/Instant exit if in profit
   EXIT_POLICY_INSTANT = 1  // instant exit anyway
};


input group "Time"
input bool use_chart_timeframe = false;
input ENUM_TIMEFRAMES costume_timeframe = PERIOD_M15;
input int market_open_hour = 2;
input int market_open_minute = 0;
input int market_duration_minutes = 90;
input int market_terminate_hour = 20;
input int market_terminate_minute = 0;
input group "Risk"
input double sl_offset_points = 50;  // sl offset points channel edge
input double risk = 2;  // risk %
input double Rr = 2;  // reward/risk ratio
input group "Position"
input bool instant_entry = true;
input double order_price_ratio = 0.5;  // order price ratio. 0 close to broken edge. 1 on the other side of the channel.
input bool close_only_half_size_on_tp = false;
input ENUM_EXIT_POLICY after_terminate_time_exit_policy = EXIT_POLICY_BREAKEVEN;  // how to close open positions when market_terminate time triggers?
input group "Trailing"
input bool trailing_stoploss = false;
input int atr_period = 100;
input double atr_channel_deviation = 2;
input int Magic = 142;  // EA's magic number

CTrade trade;
string _MO,_MT;
ENUM_TIMEFRAMES tf;
MqlRates ML, MH; // market low, high
bool market_lh_calculated = false;
int atr_handle;
bool new_candle = false;

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
      DeleteAllOrders(trade);
      run_exit_policy();
      return;
      
   }
   if(TimeCurrent() < MC){
      market_lh_calculated = false;
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
   
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   if(iClose(_Symbol,tf,1) > MH.high && iOpen(_Symbol,tf,1) <= MH.high){
      double p1_ = ML.low;
      double p2_ = MH.high;
      double p;
      if(instant_entry) p = ask;
      else p = order_price_ratio * (p1_-p2_) + p2_;
      double sl = p1_ - sl_offset_points*_Point;
      double tp = p + Rr * (p-sl);
      double lot = calculate_lot_size((p-sl)/_Point, risk);
      double lot_ = NormalizeDouble(floor(100*lot/2)/100, 2);
      if(instant_entry){
         if(close_only_half_size_on_tp){
            trade.Buy(lot_, _Symbol, p, sl, tp, DoubleToString(sl, _Digits));
            trade.Buy(lot_, _Symbol, p, sl, 0, DoubleToString(sl, _Digits));
         }else{
            trade.Buy(lot, _Symbol, p, sl, tp, DoubleToString(sl, _Digits));
         }
      }else{
         if(close_only_half_size_on_tp){
            trade.BuyLimit(lot_, p, _Symbol, sl, tp, ORDER_TIME_GTC, 0, DoubleToString(sl, _Digits));
            trade.BuyLimit(lot_, p, _Symbol, sl, 0, ORDER_TIME_GTC, 0, DoubleToString(sl, _Digits));
         }else{
            trade.BuyLimit(lot, p, _Symbol, sl, tp, ORDER_TIME_GTC, 0, DoubleToString(sl, _Digits));
         }
      }

   }else if(iClose(_Symbol,tf,1) < ML.low && iOpen(_Symbol,tf,1) >= ML.low){
      double p1_ = MH.high;
      double p2_ = ML.low;
      double p;
      if(instant_entry) p = bid;
      else p = order_price_ratio * (p1_-p2_) + p2_;
      double sl = p1_ + sl_offset_points*_Point;
      double tp = p - Rr * (sl-p);
      double lot = calculate_lot_size((sl-p)/_Point, risk);
      double lot_ = NormalizeDouble(floor(100*lot/2)/100, 2);
      if(instant_entry){
         if(close_only_half_size_on_tp){
            trade.Sell(lot_, _Symbol, p, sl, tp, DoubleToString(sl, _Digits));
            trade.Sell(lot_, _Symbol, p, sl, 0, DoubleToString(sl, _Digits));
         }else{
            trade.Sell(lot, _Symbol, p, sl, tp, DoubleToString(sl, _Digits));
         }
      }else{
         if(close_only_half_size_on_tp){
            trade.SellLimit(lot_, p, _Symbol, sl, tp, ORDER_TIME_GTC, 0, DoubleToString(sl, _Digits));
            trade.SellLimit(lot_, p, _Symbol, sl, 0, ORDER_TIME_GTC, 0, DoubleToString(sl, _Digits));
         }else{
            trade.Sell(lot, _Symbol, p, sl, tp, DoubleToString(sl, _Digits));
         }
      }
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
            for(int i=0;i<npos;i++){  
               PositionSelectByTicket(pos_tickets[i]);
               sl = PositionGetDouble(POSITION_PRICE_OPEN);                             
               trade.PositionModify(pos_tickets[i], sl, 0); 
            }
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


void run_exit_policy(void){
   if(after_terminate_time_exit_policy==EXIT_POLICY_INSTANT){
      CloseAllPositions(trade);
      return;
      
   }else if(after_terminate_time_exit_policy==EXIT_POLICY_BREAKEVEN){
      ulong pos_tickets[];
      GetMyPositionsTickets(Magic, pos_tickets);
      int npos = ArraySize(pos_tickets);  
      for(int ipos=0;ipos<npos;ipos++){
         PositionSelectByTicket(pos_tickets[ipos]);
         ENUM_POSITION_TYPE pos_type = PositionGetInteger(POSITION_TYPE);
         double current_sl = PositionGetDouble(POSITION_SL);
         double current_tp = PositionGetDouble(POSITION_TP);
         double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
         if(pos_type==POSITION_TYPE_BUY){
            double bidprice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
            double profit_points = (bidprice-open_price)/_Point;
            if(profit_points>=0) trade.PositionClose(pos_tickets[ipos]);
            else trade.PositionModify(pos_tickets[ipos], current_sl, open_price);
         }else if(pos_type==POSITION_TYPE_SELL){
            double askprice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            double profit_points = (open_price-askprice)/_Point;
            if(profit_points>=0) trade.PositionClose(pos_tickets[ipos]);
            else trade.PositionModify(pos_tickets[ipos], current_sl, open_price);              
         }
      }
      return;
   }
}