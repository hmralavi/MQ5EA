/*
ATR trailing order EA

Strategy:
   1- place atr channel on the chart
   2- if we have already placed buy/sell order, modify them. buy/sell order can only goes higher/lower buy the lower/higher atr edge.
   3- if we dont have pending order, see if there is a ascending/descending atr, if so, then place a buy/sell limit order.
*/

#include <../Experts/mq5ea/mytools.mqh>

input bool use_chart_timeframe = true;
input ENUM_TIMEFRAMES costume_timeframe = PERIOD_M5;
input double sl_points = 300;  // sl points 
input double tp_points = 3000;  // tp points 
input double lot = 0.01;  // lot size
input int atr_period = 100;
input double atr_channel_deviation = 3.6;
input int n_candles_atr_trend = 6;
input double risk_free_in_loss_trigger_points = 75; 
input double risk_free_in_profit_trigger_points = 1000; 
input int n_positions_allowed_in_one_direction = 1;
input int Magic = 170;  // EA's magic number

CTrade trade;
int atr_handle;
ENUM_TIMEFRAMES tf;

int OnInit()
{
   trade.SetExpertMagicNumber(Magic);
   if(use_chart_timeframe) tf = _Period;
   else tf = costume_timeframe;
   atr_handle = iCustom(_Symbol, tf, "..\\Experts\\mq5ea\\indicators\\atr_channel.ex5", false, atr_period, atr_channel_deviation);
   ChartIndicatorAdd(0, 0, atr_handle);
   return(INIT_SUCCEEDED);
}


void OnDeinit(const int reason)
{
   IndicatorRelease(atr_handle);
   ObjectsDeleteAll(0);
}

void OnTick()
{
   bool all_buy_positions_risk_free = true;
   bool all_sell_positions_risk_free = true;
   ulong pos_tickets[];
   GetMyPositionsTickets(Magic, pos_tickets);
   int npos = ArraySize(pos_tickets);
   int nbuypos = 0;
   int nsellpos = 0;
   
   for(int ipos=0;ipos<npos;ipos++){
   
      PositionSelectByTicket(pos_tickets[ipos]);
      ENUM_POSITION_TYPE pos_type = PositionGetInteger(POSITION_TYPE);
      double current_sl = PositionGetDouble(POSITION_SL);
      double current_tp = PositionGetDouble(POSITION_TP);
      double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      
      if(pos_type==POSITION_TYPE_BUY){
         nbuypos++;
         if(current_sl < open_price && current_tp > open_price){
            double bidprice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
            double profit_points = (bidprice-open_price)/_Point;
            if(profit_points>risk_free_in_profit_trigger_points && risk_free_in_profit_trigger_points>0){
               trade.PositionModify(pos_tickets[ipos], open_price, current_tp);
            }else if(profit_points<-risk_free_in_loss_trigger_points && risk_free_in_loss_trigger_points>0){
               trade.PositionModify(pos_tickets[ipos], current_sl, open_price);
            }
         }
         PositionSelectByTicket(pos_tickets[ipos]);
         current_sl = PositionGetDouble(POSITION_SL);
         if(current_sl<open_price) all_buy_positions_risk_free = false;
         
      }else if(pos_type==POSITION_TYPE_SELL){
         nsellpos++;
         if(current_sl > open_price && current_tp < open_price){
            double askprice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            double profit_points = (open_price-askprice)/_Point;
            if(profit_points>risk_free_in_profit_trigger_points && risk_free_in_profit_trigger_points>0){
               trade.PositionModify(pos_tickets[ipos], open_price, current_tp);
            }else if(profit_points<-risk_free_in_loss_trigger_points && risk_free_in_loss_trigger_points>0){
               trade.PositionModify(pos_tickets[ipos], current_sl, open_price);
            }
         }
         PositionSelectByTicket(pos_tickets[ipos]);
         current_sl = PositionGetDouble(POSITION_SL);
         if(current_sl>open_price) all_sell_positions_risk_free = false;              
      }
   }

   
   if(!IsNewCandle(tf)) return;
   
   double atrlow[], atrhigh[];
   ArraySetAsSeries(atrlow, true);
   ArraySetAsSeries(atrhigh, true);
   CopyBuffer(atr_handle, 6, 1, n_candles_atr_trend, atrlow);  // buffer 5 atrhigh, buffer 6 atrlow
   CopyBuffer(atr_handle, 5, 1, n_candles_atr_trend, atrhigh);  // buffer 5 atrhigh, buffer 6 atrlow

   ulong ord_tickets[];
   GetMyOrdersTickets(Magic, ord_tickets);
   int nord = ArraySize(ord_tickets);
   if(nord>2){
      Alert("More than 2 orders exist!!!");
      return;
   }
   ulong buy_order = 0;
   ulong sell_order = 0;
   for(int iord=0;iord<nord;iord++){
      OrderSelect(ord_tickets[iord]);
      ENUM_ORDER_TYPE ord_type = OrderGetInteger(ORDER_TYPE);
      if(ord_type==ORDER_TYPE_BUY_LIMIT) buy_order = ord_tickets[iord];
      if(ord_type==ORDER_TYPE_SELL_LIMIT) sell_order = ord_tickets[iord];
   }
   
   if(buy_order==0){   
      if(n_positions_allowed_in_one_direction>nbuypos && all_buy_positions_risk_free){ // place buy order
         bool is_atr_trendy = true;
         //for(int iatr=0;iatr<n_candles_atr_trend-1;iatr++) is_atr_trendy = is_atr_trendy && (atrlow[iatr]>atrlow[iatr+1]);
         is_atr_trendy = atrlow[0]>atrlow[n_candles_atr_trend-1];
         if(is_atr_trendy){
            double pr = NormalizeDouble(atrlow[0], _Digits);
            double sl = NormalizeDouble(pr - sl_points*_Point, _Digits);
            double tp = NormalizeDouble(pr + tp_points*_Point, _Digits);
            trade.BuyLimit(lot, pr, _Symbol, sl, tp);
         }
      }
   }else{   // modify buy order
      OrderSelect(buy_order);
      double oldpr = OrderGetDouble(ORDER_PRICE_OPEN);
      double newpr = atrlow[0];
      double sl = NormalizeDouble(newpr - sl_points*_Point, _Digits);
      double tp = NormalizeDouble(newpr + tp_points*_Point, _Digits);
      if(newpr>oldpr) trade.OrderModify(buy_order, newpr, sl, tp, ORDER_TIME_GTC, 0);      
   }
   
   
   if(sell_order==0){
      if(n_positions_allowed_in_one_direction>nsellpos && all_sell_positions_risk_free){ // place sell order
         bool is_atr_trendy = true;
         //for(int iatr=0;iatr<n_candles_atr_trend-1;iatr++) is_atr_trendy = is_atr_trendy && (atrhigh[iatr]<atrhigh[iatr+1]);
         is_atr_trendy = atrhigh[0]<atrhigh[n_candles_atr_trend-1];
         if(is_atr_trendy){
            double pr = NormalizeDouble(atrhigh[0], _Digits);
            double sl = NormalizeDouble(pr + sl_points*_Point, _Digits);
            double tp = NormalizeDouble(pr - tp_points*_Point, _Digits);
            trade.SellLimit(lot, pr, _Symbol, sl, tp);
         }         
      }
   }else{   // modify sell order
      OrderSelect(sell_order);
      double oldpr = OrderGetDouble(ORDER_PRICE_OPEN);
      double newpr = atrhigh[0];
      double sl = NormalizeDouble(newpr + sl_points*_Point, _Digits);
      double tp = NormalizeDouble(newpr - tp_points*_Point, _Digits);
      if(newpr<oldpr) trade.OrderModify(sell_order, newpr, sl, tp, ORDER_TIME_GTC, 0);                  
   }
}

