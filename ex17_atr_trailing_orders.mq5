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
input double sl_points = 50;  // sl points 
input double tp_points = 70;  // tp points 
input double lot = 0.01;  // lot size
input int atr_period = 100;
input double atr_channel_deviation = 2;
input int n_candles_atr_trend = 5;
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
   if(!IsNewCandle(tf)) return;
   
   double atrlow[], atrhigh[];
   ArraySetAsSeries(atrlow, true);
   ArraySetAsSeries(atrhigh, true);
   CopyBuffer(atr_handle, 6, 1, n_candles_atr_trend, atrlow);  // buffer 5 atrhigh, buffer 6 atrlow
   CopyBuffer(atr_handle, 5, 1, n_candles_atr_trend, atrhigh);  // buffer 5 atrhigh, buffer 6 atrlow
   
   ulong pos_tickets[], ord_tickets[];
   GetMyPositionsTickets(Magic, pos_tickets);
   GetMyOrdersTickets(Magic, ord_tickets);
   int npos = ArraySize(pos_tickets);
   int nord = ArraySize(ord_tickets);
   if(npos+nord>2){
      Alert("norders+npositions > 2!");
      return;
   }
   ulong buypos, sellpos, buyord, sellord;
   buypos = 0;
   sellpos = 0;
   buyord = 0;
   sellord = 0;
   for(int ipos=0;ipos<npos;ipos++){
      PositionSelectByTicket(pos_tickets[ipos]);
      ENUM_POSITION_TYPE pos_type = PositionGetInteger(POSITION_TYPE);
      if(pos_type==POSITION_TYPE_BUY) buypos = pos_tickets[ipos];
      if(pos_type==POSITION_TYPE_SELL) sellpos = pos_tickets[ipos];
   }
   for(int iord=0;iord<nord;iord++){
      OrderSelect(ord_tickets[iord]);
      ENUM_ORDER_TYPE ord_type = OrderGetInteger(ORDER_TYPE);
      if(ord_type==ORDER_TYPE_BUY_LIMIT) buyord = ord_tickets[iord];
      if(ord_type==ORDER_TYPE_SELL_LIMIT) sellord = ord_tickets[iord];
   }
   
   if(buypos==0){
      if(buyord==0){   // place buy order
         bool is_atr_trendy=true;
         //for(int iatr=0;iatr<n_candles_atr_trend-1;iatr++) is_atr_trendy = is_atr_trendy && (atrlow[iatr]>atrlow[iatr+1]);
         is_atr_trendy = atrlow[0]>atrlow[n_candles_atr_trend-1];
         if(is_atr_trendy){
            double pr = NormalizeDouble(atrlow[0], _Digits);
            double sl = NormalizeDouble(pr - sl_points*_Point, _Digits);
            double tp = NormalizeDouble(pr + tp_points*_Point, _Digits);
            trade.BuyLimit(lot, pr, _Symbol, sl, tp);
         }
      }else{   // modify buy order
         OrderSelect(buyord);
         double oldpr = OrderGetDouble(ORDER_PRICE_OPEN);
         double newpr = atrlow[0];
         double sl = NormalizeDouble(newpr - sl_points*_Point, _Digits);
         double tp = NormalizeDouble(newpr + tp_points*_Point, _Digits);
         if(newpr>oldpr) trade.OrderModify(buyord, newpr, sl, tp, ORDER_TIME_GTC, 0);      
      }
   }
   
   if(sellpos==0){
      if(sellord==0){   // place sell order
         bool is_atr_trendy=true;
         //for(int iatr=0;iatr<n_candles_atr_trend-1;iatr++) is_atr_trendy = is_atr_trendy && (atrhigh[iatr]<atrhigh[iatr+1]);
         is_atr_trendy = atrhigh[0]<atrhigh[n_candles_atr_trend-1];
         if(is_atr_trendy){
            double pr = NormalizeDouble(atrhigh[0], _Digits);
            double sl = NormalizeDouble(pr + sl_points*_Point, _Digits);
            double tp = NormalizeDouble(pr - tp_points*_Point, _Digits);
            trade.SellLimit(lot, pr, _Symbol, sl, tp);
         }         
      }else{   // modify sell order
         OrderSelect(sellord);
         double oldpr = OrderGetDouble(ORDER_PRICE_OPEN);
         double newpr = atrhigh[0];
         double sl = NormalizeDouble(newpr + sl_points*_Point, _Digits);
         double tp = NormalizeDouble(newpr - tp_points*_Point, _Digits);
         if(newpr<oldpr) trade.OrderModify(sellord, newpr, sl, tp, ORDER_TIME_GTC, 0);                  
      }
   
   }

}

