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

enum ENUM_ENTER_POLICY{
   ENTER_POLICY_INSTANT_ON_CANDLE_CLOSE = 0,  // instant entry on candle close
   ENTER_POLICY_ORDER_ON_BROKEN_LEVEL = 1  // pending order on the broken level
};

input group "Time settings"
input bool use_chart_timeframe = false;
input ENUM_CUSTOM_TIMEFRAMES custom_timeframe = CUSTOM_TIMEFRAMES_H1;
input bool confirm_with_higher_timeframe = true;
input ENUM_CUSTOM_TIMEFRAMES higher_timeframe = CUSTOM_TIMEFRAMES_D1;
input ENUM_MONTH trading_month=MONTH_JAN;  // trade only in this month

input group "Indicator settings"
input int n_candles_peak = 6;
input int static_or_dynamic_trendline = 0;  // set 1 for static or 2 for trendline, set 0 for both

input group "Position settings"
input ENUM_ENTER_POLICY enter_policy = ENTER_POLICY_ORDER_ON_BROKEN_LEVEL;
input ENUM_EARLY_EXIT_POLICY early_exit_policy = EARLY_EXIT_POLICY_BREAKEVEN;  // how exit position when trend changes?
input int min_bos_number = 0;
input int max_bos_number = 0;
input double winrate_min = 0;
input double winrate_max = 0;
input double profit_factor_min = 0;
input double profit_factor_max = 0;
input int backtest_period = 10;

input group "Risk settings"
input double risk_original = 100;  // risk usd per trade
input double sl_points_offset = 100;  // sl points offset from peak
input ENUM_TP_POLICY tp_policy = TP_POLICY_BASED_ON_PEAK;
input double Rr = 2;  // fixed(minimum) reward/risk ratio 

input group "Trailing Stoploss"
input bool trailing_stoploss = false;
input double tsl_offset_points = 300;

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
double risk;
PropChallengeCriteria prop_challenge_criteria;

#define HIGH_BUFFER 1
#define LOW_BUFFER 2
#define BOS_BUFFER 5
#define BROKEN_LEVEL_BUFFER 6
#define WINRATE_BUFFER 8
#define PROFIT_BUFFER 9
#define LOSS_BUFFER 10
#define TREND_BUFFER 12
#define PEAK_BUFFER 13
#define PEAK_BROKEN_BUFFER 14

int OnInit()
{
   trade.SetExpertMagicNumber(Magic);
   trade.LogLevel(LOG_LEVEL_NO);
   if(use_chart_timeframe) tf = _Period;
   else tf = convert_tf(custom_timeframe);
   bool do_backtest = winrate_min>0 || winrate_max>0 || profit_factor_min>0 || profit_factor_max>0;
   ind_handle1 = iCustom(_Symbol, tf, "..\\Experts\\mq5ea\\indicators\\choch_detector.ex5", n_candles_peak, static_or_dynamic_trendline, do_backtest, backtest_period);
   ChartIndicatorAdd(0, 0, ind_handle1);
   if(confirm_with_higher_timeframe){
      ind_handle2 = iCustom(_Symbol, convert_tf(higher_timeframe), "..\\Experts\\mq5ea\\indicators\\choch_detector.ex5", n_candles_peak, static_or_dynamic_trendline, false);
      ChartIndicatorAdd(0, 0, ind_handle2);
   }
   risk = risk_original;
   prop_challenge_criteria = PropChallengeCriteria(prop_challenge_min_profit_usd, prop_challenge_max_drawdown_usd, trading_month, Magic);
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
   
   double period_prof, period_drawdown, today_profit; 
   if(prop_challenge_criteria_enabled){
      prop_challenge_criteria.update();
      period_prof = prop_challenge_criteria.get_current_period_profit();
      period_drawdown = prop_challenge_criteria.get_current_period_drawdown();
      today_profit = prop_challenge_criteria.get_today_profit();
      if(!MQLInfoInteger(MQL_TESTER) || MQLInfoInteger(MQL_VISUAL_MODE)) Comment("EA: ", Magic, "\nToday profit: ", int(today_profit),"\nPeriod Profit: ", int(period_prof), " / " , int(prop_challenge_min_profit_usd), "\nPeriod Drawdown: ", int(period_drawdown), " / " , int(prop_challenge_max_drawdown_usd), "\nRisk: ", int(risk), " / " , int(prop_challenge_daily_loss_limit));
      if(period_prof>=prop_challenge_min_profit_usd*1.01 && risk>new_risk_if_prop_passed){
         DeleteAllOrders(trade);
         CloseAllPositions(trade);
      }
   }
   
   ulong pos_tickets[];
   GetMyPositionsTickets(Magic, pos_tickets);
   
   if(trailing_stoploss){
      int npos = ArraySize(pos_tickets);
      for(int ipos=0;ipos<npos;ipos++){
         PositionSelectByTicket(pos_tickets[ipos]);
         ENUM_POSITION_TYPE pos_type = PositionGetInteger(POSITION_TYPE);
         double open_price = PositionGetDouble(POSITION_PRICE_OPEN);      
         double curr_sl = PositionGetDouble(POSITION_SL);
         double trigger_points = 0;
         if(pos_type==POSITION_TYPE_BUY && curr_sl<open_price) trigger_points = (open_price-curr_sl)/_Point;
         if(pos_type==POSITION_TYPE_SELL && curr_sl>open_price) trigger_points = (curr_sl-open_price)/_Point;
         TrailingStoploss(trade, pos_tickets[ipos], tsl_offset_points, trigger_points);         
      }
   }   
   
   if(!IsNewCandle(tf, 10)) return;   
      
   double trend[], bos[], higher_trend[1], winrate[1], profit_points[1], loss_points[1];
   ArraySetAsSeries(trend, true);
   ArraySetAsSeries(bos, true);
   ArraySetAsSeries(higher_trend, true);
   ArraySetAsSeries(winrate, true);
   ArraySetAsSeries(loss_points, true);
   ArraySetAsSeries(winrate, true);
   CopyBuffer(ind_handle1, TREND_BUFFER, 1, 2, trend);
   CopyBuffer(ind_handle1, BOS_BUFFER, 1, 2, bos);
   if(confirm_with_higher_timeframe) CopyBuffer(ind_handle2, TREND_BUFFER, 1, 1, higher_trend);
   if(winrate_min>0 || winrate_max>0 || profit_factor_min>0 || profit_factor_max>0){
      CopyBuffer(ind_handle1, WINRATE_BUFFER, 1, 1, winrate);
      CopyBuffer(ind_handle1, PROFIT_BUFFER, 1, 1, profit_points);
      CopyBuffer(ind_handle1, LOSS_BUFFER, 1, 1, loss_points);
   }
   
   if(trend[0]!=trend[1]){
      DeleteAllOrders(trade);
      run_early_exit_policy();
   }
   
   ArrayResize(pos_tickets, 0);
   GetMyPositionsTickets(Magic, pos_tickets);
   
   if(trading_month>0){
      MqlDateTime current_date;
      TimeToStruct(TimeCurrent(), current_date);
      if(current_date.mon != trading_month) return;
   }   
   
   if(prop_challenge_criteria_enabled){
      if(prop_challenge_criteria.is_current_period_passed()){
         risk = new_risk_if_prop_passed;
      }else{
         double risk_to_reach_drawdown = period_prof + prop_challenge_max_drawdown_usd;
         risk = MathMin(risk_original, risk_to_reach_drawdown);
      }
      if(today_profit-risk*1.01<=-prop_challenge_daily_loss_limit) return;
      if(!prop_challenge_criteria.is_current_period_drawdown_passed()) return;
   }
   
   if(ArraySize(pos_tickets)>0) return;
   if(min_bos_number>0 && bos[0]<min_bos_number) return;
   if(max_bos_number>0 && bos[0]>max_bos_number) return;
   if(winrate_min>0 && winrate[0]<winrate_min) return;
   if(winrate_max>0 && winrate[0]>winrate_max) return;
   if(profit_factor_min>0 && MathAbs(profit_points[0]/loss_points[0])<profit_factor_min) return;
   if(profit_factor_max>0 && MathAbs(profit_points[0]/loss_points[0])>profit_factor_max) return;  
   
   if(trend[0]==1 && (bos[0]!=bos[1] || trend[0]!=trend[1]) && (!confirm_with_higher_timeframe || (higher_trend[0]==1 && confirm_with_higher_timeframe))){  // enter buy
      double p = 0;
      if(enter_policy==ENTER_POLICY_INSTANT_ON_CANDLE_CLOSE) p = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      else if(enter_policy==ENTER_POLICY_ORDER_ON_BROKEN_LEVEL){
         DeleteAllOrders(trade);
         double broken_level[];
         ArraySetAsSeries(broken_level, true);
         CopyBuffer(ind_handle1, BROKEN_LEVEL_BUFFER, 1, 1, broken_level);
         p = broken_level[0];
      }
      p = NormalizeDouble(p, _Digits);
      double sl = find_nearest_unbroken_peak_price(false, 0, p);
      if(sl<0) return;
      sl = sl - sl_points_offset*_Point;
      double tp;
      if(tp_policy == TP_POLICY_BASED_ON_PEAK){
         double mintp = p + (p - sl) * Rr;
         tp = find_nearest_unbroken_peak_price(true, mintp);
         if(tp<0) return;
         tp = tp - sl_points_offset*_Point;
      }else if(tp_policy == TP_POLICY_BASED_ON_FIXED_RR){
         tp = p + (p - sl) * Rr;
      }
      sl = NormalizeDouble(sl ,_Digits);
      tp = NormalizeDouble(tp, _Digits);
      double _Rr = (tp-p)/(p-sl);
      double lot_size = normalize_volume(calculate_lot_size((p-sl)/_Point, risk));
      
      if(enter_policy==ENTER_POLICY_INSTANT_ON_CANDLE_CLOSE) trade.Buy(lot_size, _Symbol, p, sl, tp, PositionComment);
      else if(enter_policy==ENTER_POLICY_ORDER_ON_BROKEN_LEVEL) trade.BuyLimit(lot_size, p, _Symbol, sl, tp, ORDER_TIME_GTC, 0, PositionComment);      
   
   }else if(trend[0]==2 && (bos[0]!=bos[1] || trend[0]!=trend[1]) && (!confirm_with_higher_timeframe || (higher_trend[0]==2 && confirm_with_higher_timeframe))){  // enter sell
      double p = 0;
      if(enter_policy==ENTER_POLICY_INSTANT_ON_CANDLE_CLOSE) p = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      else if(enter_policy==ENTER_POLICY_ORDER_ON_BROKEN_LEVEL){
         DeleteAllOrders(trade);
         double broken_level[];
         ArraySetAsSeries(broken_level, true);
         CopyBuffer(ind_handle1, BROKEN_LEVEL_BUFFER, 1, 1, broken_level);
         p = broken_level[0];
      }
      p = NormalizeDouble(p, _Digits);
      double sl = find_nearest_unbroken_peak_price(true, p);
      if(sl<0) return;
      sl = sl + sl_points_offset*_Point;
      double tp;
      if(tp_policy == TP_POLICY_BASED_ON_PEAK){
         double mintp = p - (sl - p) * Rr;
         tp = find_nearest_unbroken_peak_price(false, 0, mintp);
         if(tp<0) return;
         tp = tp + sl_points_offset*_Point;
      }else if(tp_policy == TP_POLICY_BASED_ON_FIXED_RR){
         tp = p - (sl - p) * Rr;
      }
      sl = NormalizeDouble(sl ,_Digits);
      tp = NormalizeDouble(tp, _Digits);
      double _Rr = (p-tp)/(sl-p);
      double lot_size = normalize_volume(calculate_lot_size((sl-p)/_Point, risk));
      
      if(enter_policy==ENTER_POLICY_INSTANT_ON_CANDLE_CLOSE) trade.Sell(lot_size, _Symbol, p, sl, tp, PositionComment);
      else if(enter_policy==ENTER_POLICY_ORDER_ON_BROKEN_LEVEL) trade.SellLimit(lot_size, p, _Symbol, sl, tp, ORDER_TIME_GTC, 0, PositionComment);      
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
   datetime passed_periods[];
   double result = prop_challenge_criteria.get_results(passed_periods);
   int n = ArraySize(passed_periods);
   Print("PASSED PERIODS");
   Print("-----------------");
   for(int i=0;i<n;i++) Print(passed_periods[i]);
   Print("-----------------");
   return result;   
}