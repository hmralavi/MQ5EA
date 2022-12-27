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
#include <../Experts/mq5ea/prop_challenge_tools.mqh>

enum ENUM_EARLY_EXIT_POLICY{
   EARLY_EXIT_POLICY_BREAKEVEN = 0,  // Breakeven if in loss/Instant exit if in profit
   EARLY_EXIT_POLICY_INSTANT = 1  // instant exit anyway
};

enum ENUM_TP_POLICY{
   TP_POLICY_BASED_ON_FIXED_RR = 0,  // Set tp based on a fixed Rr
   TP_POLICY_BASED_ON_PEAK = 1  // Set tp based on recent peak and minimum Rr
};

input group "Time settings"
input bool use_costume_timeframe = false;
input ENUM_TIMEFRAMES costume_timeframe = PERIOD_H1;
input bool confirm_with_higher_timeframe = true;
input ENUM_TIMEFRAMES higher_timeframe = PERIOD_D1;
input ENUM_MONTH trading_month=MONTH_JAN;  // trade only in this month

input group "Indicator settings"
input int n_candles_peak = 6;
input int static_or_dynamic_trendline = 0;  // set 1 for static or 2 for trendline, set 0 for both

input group "Position settings"
input double sl_points_offset = 100;  // sl points offset from peak
input double risk_original = 100;  // risk usd per trade
input ENUM_EARLY_EXIT_POLICY early_exit_policy = EARLY_EXIT_POLICY_BREAKEVEN;  // how exit position when trend changes?
input ENUM_TP_POLICY tp_policy = TP_POLICY_BASED_ON_PEAK;
input double Rr = 2;  // fixed(minimum) reward/risk ratio 

input group "Optimization criteria for prop challenge"
input bool prop_challenge_criteria_enabled = true; // Enabled?
input double prop_challenge_min_profit_usd = 800; // Min profit desired(usd);
input double prop_challenge_max_drawdown_usd = 1200;  // Max drawdown desired(usd);
input double prop_challenge_daily_loss_limit = 450;  // Max loss (usd) in one day
input double new_risk_if_prop_passed = 10; // new risk (usd) if prop challenge is passed.

input group "EA settings"
input double equity_stop_trading = 0;  // Stop trading if account equity is above this:
input string PositionComment = "";
input int Magic = 200;  // EA's magic number

CTrade trade;
int ind_handle1, ind_handle2;
ENUM_TIMEFRAMES tf;
double risk = risk_original;
PropChallengeCriteria prop_challenge_criteria(prop_challenge_min_profit_usd, prop_challenge_max_drawdown_usd, trading_month, Magic);

#define HIGH_BUFFER 1
#define LOW_BUFFER 2
#define TREND_BUFFER 7
#define PEAK_BUFFER 8
#define PEAK_BROKEN_BUFFER 9

int OnInit()
{
   trade.SetExpertMagicNumber(Magic);
   if(use_costume_timeframe) tf = costume_timeframe;
   else tf = _Period;
   ind_handle1 = iCustom(_Symbol, tf, "..\\Experts\\mq5ea\\indicators\\choch_detector.ex5", n_candles_peak, static_or_dynamic_trendline);
   ind_handle2 = iCustom(_Symbol, higher_timeframe, "..\\Experts\\mq5ea\\indicators\\choch_detector.ex5", n_candles_peak, static_or_dynamic_trendline);
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

   if(equity_stop_trading>0){
      double acc_eq = AccountInfoDouble(ACCOUNT_EQUITY);
      if(acc_eq>=equity_stop_trading){
         CloseAllPositions(trade);
         DeleteAllOrders(trade);
         return;
      }
   }
   
   if(prop_challenge_criteria_enabled){
      prop_challenge_criteria.update();
      if(prop_challenge_criteria.is_current_period_passed() && risk>=risk_original){
         CloseAllPositions(trade);
         DeleteAllOrders(trade);
      }
   }
   
   if(!IsNewCandle(tf)) return;   
      
   double trend[], higher_trend[];
   ArraySetAsSeries(trend, true);
   ArraySetAsSeries(higher_trend, true);
   CopyBuffer(ind_handle1, TREND_BUFFER, 1, 2, trend);
   CopyBuffer(ind_handle2, TREND_BUFFER, 1, 1, higher_trend);
   
   if(trend[0]!=trend[1]) run_early_exit_policy();
   
   if(trading_month>0){
      MqlDateTime current_date;
      TimeToStruct(TimeCurrent(), current_date);
      if(current_date.mon != trading_month) return;
   }
   
   if(prop_challenge_criteria_enabled){
      if(prop_challenge_criteria.is_current_period_passed()) risk = new_risk_if_prop_passed;
      else risk = risk_original;
      double today_profit = prop_challenge_criteria.get_today_profit();
      if(today_profit-risk*1.01<=-prop_challenge_daily_loss_limit) return;
      if(!prop_challenge_criteria.is_current_period_drawdown_passed()) return;
   }
   
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
      double lot_size = calculate_lot_size((ask-sl)/_Point, risk);
      trade.Buy(lot_size, _Symbol, ask, sl, tp, PositionComment);
   
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
      double lot_size = calculate_lot_size((sl-bid)/_Point, risk);
      trade.Sell(lot_size, _Symbol, bid, sl, tp, PositionComment);    
   }

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
      if(peaks[i]==1 && broken[i]==0 && findtop && high[i]>=higherthan && high[i]<=lowerthan){
         double hi = high[i];
         for(int j=i-1;j>0;j--){
            if(high[j]>hi) hi = high[j];
         }
         return hi;
      }
      if(peaks[i]==2 && broken[i]==0 && !findtop && low[i]>=higherthan && low[i]<=lowerthan){
         double lo = low[i];
         for(int j=i-1;j>0;j--){
            if(low[j]<lo) lo = low[j];
         }
         return lo;
      }
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

double OnTester(void){
   return prop_challenge_criteria.get_results();
}