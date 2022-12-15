/*
Choch entry EA

Strategy:
   1- use choch_detector indicator
   2- wait for a new candle
   3- look at the last closed candle, if the trend has been changed, enter position
   4- place sl at the last peak
   5- consider risk percent for calculating lot size
   6- set tp accorfing to reward/risk ratio
*/

#include <../Experts/mq5ea/mytools.mqh>

enum ENUM_EARLY_EXIT_POLICY{
   EARLY_EXIT_POLICY_BREAKEVEN = 0,  // Breakeven if in loss/Instant exit if in profit
   EARLY_EXIT_POLICY_INSTANT = 1  // instant exit anyway
};

enum ENUM_TP_POLICY{
   TP_POLICY_BASED_ON_FIXED_RR = 0,  // Set tp based on a fixed Rr
   TP_POLICY_BASED_ON_PEAK = 1  // Set tp based on recent peak and minimum Rr
};

input group "Indicator settings"
input bool use_costume_timeframe = false;
input ENUM_TIMEFRAMES costume_timeframe = PERIOD_H1;
input bool confirm_with_higher_timeframe = true;
input ENUM_TIMEFRAMES higher_timeframe = PERIOD_D1;
input int n_candles_peak = 6;

input group "Position settings"
input double sl_points_offset = 100;  // sl points offset from peak
input double risk_percent = 2;  // risk percent
input ENUM_EARLY_EXIT_POLICY early_exit_policy = EARLY_EXIT_POLICY_BREAKEVEN;  // how exit position when trend changes?
input ENUM_TP_POLICY tp_policy = TP_POLICY_BASED_ON_PEAK;
input double Rr = 2;  // fixed(minimum) reward/risk ratio 

input group "EA settings"
input int Magic = 200;  // EA's magic number

CTrade trade;
int ind_handle1, ind_handle2;
ENUM_TIMEFRAMES tf;

#define HIGH_BUFFER 1
#define LOW_BUFFER 2
#define TREND_BUFFER 5
#define PEAK_BUFFER 6
#define PEAK_BROKEN_BUFFER 7

int OnInit()
{
   trade.SetExpertMagicNumber(Magic);
   if(use_costume_timeframe) tf = costume_timeframe;
   else tf = _Period;
   ind_handle1 = iCustom(_Symbol, tf, "..\\Experts\\mq5ea\\indicators\\choch_detector.ex5", n_candles_peak, 1);
   ind_handle2 = iCustom(_Symbol, higher_timeframe, "..\\Experts\\mq5ea\\indicators\\choch_detector.ex5", n_candles_peak, 1);
   ChartIndicatorAdd(0, 0, ind_handle1);
   ChartIndicatorAdd(0, 0, ind_handle2);
   return(INIT_SUCCEEDED);
}


void OnDeinit(const int reason)
{
   IndicatorRelease(ind_handle1);
   IndicatorRelease(ind_handle2);
}

void OnTick()
{ 
   if(!IsNewCandle(tf)) return;   
      
   double trend[], higher_trend[];
   ArraySetAsSeries(trend, true);
   ArraySetAsSeries(higher_trend, true);
   CopyBuffer(ind_handle1, TREND_BUFFER, 1, 2, trend);
   CopyBuffer(ind_handle2, TREND_BUFFER, 1, 1, higher_trend);
   
   if(trend[0]!=trend[1]) run_early_exit_policy();
   
   if(trend[0]==1 && trend[1]==2 && (!confirm_with_higher_timeframe || (higher_trend[0]==1 && confirm_with_higher_timeframe))){  // enter buy
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double sl = find_nearest_unbroken_peak_price(false, 0, ask);
      if(sl<0) return;
      sl = sl - sl_points_offset*_Point;
      double tp;
      if(tp_policy == TP_POLICY_BASED_ON_PEAK){
         double mintp = ask + (ask - sl) * Rr;
         tp = find_nearest_unbroken_peak_price(true, mintp);
         if(tp<0) return;
         tp = tp - sl_points_offset*_Point;
      }else if(tp_policy == TP_POLICY_BASED_ON_FIXED_RR){
         tp = ask + (ask - sl) * Rr;
      }
      sl = NormalizeDouble(sl ,_Digits);
      tp = NormalizeDouble(tp, _Digits);
      double _Rr = (tp-ask)/(ask-sl);
      double lot_size = calculate_lot_size((ask-sl)/_Point, risk_percent);
      trade.Buy(lot_size, _Symbol, ask, sl, tp);
   
   }else if(trend[0]==2 && trend[1]==1 && (!confirm_with_higher_timeframe || (higher_trend[0]==2 && confirm_with_higher_timeframe))){  // enter sell
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double sl = find_nearest_unbroken_peak_price(true, bid);
      if(sl<0) return;
      sl = sl + sl_points_offset*_Point;
      double tp;
      if(tp_policy == TP_POLICY_BASED_ON_PEAK){
         double mintp = bid - (sl - bid) * Rr;
         double tp = find_nearest_unbroken_peak_price(false, 0, mintp);
         if(tp<0) return;
         tp = tp + sl_points_offset*_Point;
      }else if(tp_policy == TP_POLICY_BASED_ON_FIXED_RR){
         tp = bid - (sl - bid) * Rr;
      }
      sl = NormalizeDouble(sl ,_Digits);
      tp = NormalizeDouble(tp, _Digits);
      double _Rr = (bid-tp)/(sl-bid);
      double lot_size = calculate_lot_size((sl-bid)/_Point, risk_percent);
      trade.Sell(lot_size, _Symbol, bid, sl, tp);    
   }

}


double calculate_lot_size(double slpoints, double risk_percent){
   double balance = MathMin(1000,AccountInfoDouble(ACCOUNT_BALANCE));
   double riskusd = risk_percent * balance / 100;
   double lot = riskusd/slpoints;
   lot = NormalizeDouble(lot, 2);
   return lot;
}


double find_nearest_unbroken_peak_price(bool findtop, double higherthan=0, double lowerthan=100000000){
   double peaks[], broken[], high[], low[];
   ArraySetAsSeries(peaks, true);
   ArraySetAsSeries(broken, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   int ncandles = 2000;
   CopyBuffer(ind_handle1, PEAK_BUFFER, 1, ncandles, peaks);
   CopyBuffer(ind_handle1, PEAK_BROKEN_BUFFER, 1, ncandles, broken);
   CopyBuffer(ind_handle1, HIGH_BUFFER, 1, ncandles, high);
   CopyBuffer(ind_handle1, LOW_BUFFER, 1, ncandles, low);
   for(int i=0;i<ncandles;i++){
      if(peaks[i]==1 && broken[i]==0 && findtop && high[i]>=higherthan && high[i]<=lowerthan) return high[i];
      if(peaks[i]==2 && broken[i]==0 && !findtop && low[i]>=higherthan && low[i]<=lowerthan) return low[i];
   }
   return -1;   
}


void run_early_exit_policy(void){
   if(early_exit_policy==EARLY_EXIT_POLICY_INSTANT){
      CloseAllPositions(trade);
      return;
      
   }else if(early_exit_policy==EARLY_EXIT_POLICY_BREAKEVEN){
      ulong pos_tickets[];
      GetMyPositionsTickets(Magic, pos_tickets);
      int npos = ArraySize(pos_tickets);  
      for(int ipos=0;ipos<npos;ipos++){
         PositionSelectByTicket(pos_tickets[ipos]);
         ENUM_POSITION_TYPE pos_type = PositionGetInteger(POSITION_TYPE);
         double current_sl = PositionGetDouble(POSITION_SL);
         double current_tp = PositionGetDouble(POSITION_TP);
         double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
         if(pos_type==POSITION_TYPE_BUY && current_sl<open_price && current_tp>open_price){
            double bidprice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
            double profit_points = (bidprice-open_price)/_Point;
            if(profit_points>=0) trade.PositionClose(pos_tickets[ipos]);
            else trade.PositionModify(pos_tickets[ipos], current_sl, open_price);
         }else if(pos_type==POSITION_TYPE_SELL && current_sl>open_price && current_tp<open_price){
            double askprice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            double profit_points = (open_price-askprice)/_Point;
            if(profit_points>=0) trade.PositionClose(pos_tickets[ipos]);
            else trade.PositionModify(pos_tickets[ipos], current_sl, open_price);              
         }
      }
      return;
   }
}