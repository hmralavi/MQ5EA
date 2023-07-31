/*
Choch entry EA

Strategy:
   1- use choch_detector indicator
   2- wait for a new candle
   3- look at the last closed candle, if the trend has been changed, enter position
   4- place sl at the last peak
   5- consider risk percent for calculating lot size
   6- set tp accorfing to reward/risk ratio
   
Features:
   1- implement news handling
   2- use adx indicator to avoid opening position in a range market
   
TODO:
   1- when trend changes, do partial close instead of closing all the volume.
*/

#include <../Experts/mq5ea/mytools.mqh>
#include <../Experts/mq5ea/prop_challenge_tools.mqh>
#include <../Experts/mq5ea/mycalendar.mqh>

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
   ENTER_POLICY_PENDING_OEDRDER = 1  // pending order
};

input group "Time settings"
input bool use_chart_timeframe = false;
input ENUM_CUSTOM_TIMEFRAMES custom_timeframe = CUSTOM_TIMEFRAMES_H1;
input bool confirm_with_higher_timeframe = true;
input ENUM_CUSTOM_TIMEFRAMES higher_timeframe = CUSTOM_TIMEFRAMES_D1;
input ENUM_MONTH trading_month=MONTH_JAN;  // trade only in this month
input bool trade_only_in_session_time = false;  // entries only in specific session time of the day
input int session_start_hour = 9;      // session start hour (server time)
input int session_end_hour = 19;    // session end hour (server time)    

input group "Indicator settings"
input int n_candles_peak = 6;
input double peak_slope_min = 0;
input int main_tf_static_or_dynamic_trendline = 0;  // main tf breakout criteria: set 1 for static or 2 for trendline, set 0 for both
input int higher_tf_static_or_dynamic_trendline = 0;  // higher tf breakout criteria: set 1 for static or 2 for trendline, set 0 for both+
input bool confirm_trending_market_with_adx = false;
input ENUM_CUSTOM_TIMEFRAMES adx_timeframe = CUSTOM_TIMEFRAMES_H1;
input bool wilder_adx = true;
input double adx_threshold = 25;

input group "Position settings"
input ENUM_ENTER_POLICY enter_policy = ENTER_POLICY_PENDING_OEDRDER;
input double pending_order_ratio = 0.5; // pending order ratio, 0 broken level, 1 on sl
input ENUM_EARLY_EXIT_POLICY early_exit_policy = EARLY_EXIT_POLICY_BREAKEVEN;  // how exit position when trend changes?
input int valid_range_min_points = 0;
input int min_bos_number = 0;
input int max_bos_number = 0;
input double winrate_min = 0;
input double winrate_max = 0;
input double profit_factor_min = 0;
input double profit_factor_max = 0;
input int backtest_period = 10;

input group "Risk settings"
input double risk_original = 100;  // risk usd per trade
input double sl_percent_offset = 5;  // sl percent offset from peak
input ENUM_TP_POLICY tp_policy = TP_POLICY_BASED_ON_PEAK;
input double Rr = 2;  // fixed(minimum) reward/risk ratio 

input group "Breakeven & Riskfree & TSL"
input double breakeven_trigger_as_sl_ratio = 0;
input double riskfree_trigger_as_tp_ratio = 0;
input double tsl_offset_as_tp_ratio = 0;

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

input group "News Handling"
input int stop_minutes_before_news = 0;
input int stop_minutes_after_news = 0;
input string country_name = "US";
input string important_news = "CPI;Interest;Nonfarm;Unemployment;GDP;NFP;PMI";

CTrade trade;
int ind_handle1, ind_handle2, adx_handle;
ENUM_TIMEFRAMES tf;
double risk;
PropChallengeCriteria prop_challenge_criteria;
CNews today_news;

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
   ind_handle1 = iCustom(_Symbol, tf, "..\\Experts\\mq5ea\\indicators\\choch_detector.ex5", n_candles_peak, peak_slope_min, main_tf_static_or_dynamic_trendline, do_backtest, backtest_period, true, false);
   ChartIndicatorAdd(0, 0, ind_handle1);
   if(confirm_with_higher_timeframe){
      ind_handle2 = iCustom(_Symbol, convert_tf(higher_timeframe), "..\\Experts\\mq5ea\\indicators\\choch_detector.ex5", n_candles_peak, peak_slope_min, higher_tf_static_or_dynamic_trendline, false, backtest_period, true, false);
      ChartIndicatorAdd(0, 0, ind_handle2);
   }
   if(confirm_trending_market_with_adx){
      ENUM_TIMEFRAMES adxtf = convert_tf(adx_timeframe);
      if(wilder_adx) adx_handle = iADXWilder(_Symbol, adxtf, 14);
      else adx_handle = iADX(_Symbol, adxtf, 14);
   }
   risk = risk_original;
   prop_challenge_criteria = PropChallengeCriteria(prop_challenge_min_profit_usd, prop_challenge_max_drawdown_usd, trading_month, Magic);
   return(INIT_SUCCEEDED);
}


void OnDeinit(const int reason)
{
   IndicatorRelease(ind_handle1);
   IndicatorRelease(ind_handle2);
   IndicatorRelease(adx_handle);
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
   
   ulong pos_tickets[], ord_tickets[];
   GetMyPositionsTickets(Magic, pos_tickets);
   GetMyOrdersTickets(Magic, ord_tickets);
   
   if(stop_minutes_before_news>0 || stop_minutes_after_news>0){
      update_news();
      int nnews = ArraySize(today_news.news);
      if(nnews>0){
         for(int inews=0;inews<nnews;inews++){
            datetime newstime = today_news.news[inews].time;
            int nminutes = (TimeCurrent()-newstime)/60;
            if((nminutes<0 && -nminutes<=stop_minutes_before_news && stop_minutes_before_news>0) || (nminutes>0 && nminutes<=stop_minutes_after_news && stop_minutes_after_news>0)){
               if(ArraySize(pos_tickets)+ArraySize(ord_tickets)>0){
                  PrintFormat("%d minutes %s news `%s` with importance %d. closing the positions...", 
                              MathAbs(nminutes),nminutes>0?"after":"before",today_news.news[inews].title, today_news.news[inews].importance);
                  DeleteAllOrders(trade);
                  CloseAllPositions(trade);
               }
               return;
            }
         }
      }
   }   
   
   if(breakeven_trigger_as_sl_ratio>0){
      int npos = ArraySize(pos_tickets);
      for(int ipos=0;ipos<npos;ipos++){
         PositionSelectByTicket(pos_tickets[ipos]);
         ENUM_POSITION_TYPE pos_type = PositionGetInteger(POSITION_TYPE);
         double open_price = PositionGetDouble(POSITION_PRICE_OPEN);      
         double curr_sl = PositionGetDouble(POSITION_SL);
         double curr_price = PositionGetDouble(POSITION_PRICE_CURRENT);
         double curr_tp = PositionGetDouble(POSITION_TP);
         if(pos_type==POSITION_TYPE_BUY && curr_sl<open_price && curr_tp>open_price && curr_price<open_price-(open_price-curr_sl)*breakeven_trigger_as_sl_ratio){
            trade.PositionModify(pos_tickets[ipos], curr_sl, open_price);
         }else if(pos_type==POSITION_TYPE_SELL && curr_sl>open_price && curr_tp<open_price && curr_price>open_price-(open_price-curr_sl)*breakeven_trigger_as_sl_ratio){
            trade.PositionModify(pos_tickets[ipos], curr_sl, open_price);
         }   
      }
   }   
   
   if(riskfree_trigger_as_tp_ratio>0){
      int npos = ArraySize(pos_tickets);
      for(int ipos=0;ipos<npos;ipos++){
         PositionSelectByTicket(pos_tickets[ipos]);
         ENUM_POSITION_TYPE pos_type = PositionGetInteger(POSITION_TYPE);
         double open_price = PositionGetDouble(POSITION_PRICE_OPEN);      
         double curr_sl = PositionGetDouble(POSITION_SL);
         double curr_price = PositionGetDouble(POSITION_PRICE_CURRENT);
         double curr_tp = PositionGetDouble(POSITION_TP);
         if(pos_type==POSITION_TYPE_BUY && curr_tp>open_price && curr_price>open_price+(curr_tp-open_price)*riskfree_trigger_as_tp_ratio){
            if(curr_sl<open_price) trade.PositionModify(pos_tickets[ipos], open_price, curr_tp);
            if(tsl_offset_as_tp_ratio>0) TrailingStoploss(trade, pos_tickets[ipos], (curr_tp-open_price)*tsl_offset_as_tp_ratio/_Point);
         }else if(pos_type==POSITION_TYPE_SELL && curr_tp<open_price && curr_price<open_price+(curr_tp-open_price)*riskfree_trigger_as_tp_ratio){
            if(curr_sl>open_price) trade.PositionModify(pos_tickets[ipos], open_price, curr_tp);
            if(tsl_offset_as_tp_ratio>0) TrailingStoploss(trade, pos_tickets[ipos], (open_price-curr_tp)*tsl_offset_as_tp_ratio/_Point);
         }   
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
   if(!is_session_time_allowed_int(session_start_hour, session_end_hour) && trade_only_in_session_time) return;
   if(confirm_trending_market_with_adx){
      double adxmain[], adxplus[], adxminus[];
      ArraySetAsSeries(adxmain, true);
      ArraySetAsSeries(adxplus, true);
      ArraySetAsSeries(adxminus, true);
      CopyBuffer(adx_handle, 0, 0, 1, adxmain);
      CopyBuffer(adx_handle, 1, 0, 1, adxplus);
      CopyBuffer(adx_handle, 2, 0, 1, adxminus);
      if(adxmain[0]<adx_threshold) return;
   }


   if(trend[0]==1 && (bos[0]!=bos[1] || trend[0]!=trend[1]) && (!confirm_with_higher_timeframe || (higher_trend[0]==1 && confirm_with_higher_timeframe))){  // enter buy
      double p = 0;
      double broken_level[];
      ArraySetAsSeries(broken_level, true);
      CopyBuffer(ind_handle1, BROKEN_LEVEL_BUFFER, 1, 1, broken_level);
      if(enter_policy==ENTER_POLICY_INSTANT_ON_CANDLE_CLOSE) p = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      else if(enter_policy==ENTER_POLICY_PENDING_OEDRDER){
         DeleteAllOrders(trade);
         p = broken_level[0];
      }
      p = NormalizeDouble(p, _Digits);
      double sl = find_nearest_unbroken_peak_price(false, 0, p);
      if(sl<0) return;
      if(MathAbs(broken_level[0]-sl)/_Point<valid_range_min_points) return;
      if(enter_policy==ENTER_POLICY_PENDING_OEDRDER) p -= (p-sl)*pending_order_ratio;
      sl -= (broken_level[0]-sl)*sl_percent_offset/100;
      double tp;
      if(tp_policy == TP_POLICY_BASED_ON_PEAK){
         double mintp = p + (p - sl) * Rr;
         tp = find_nearest_unbroken_peak_price(true, mintp);
         if(tp<0) return;
      }else if(tp_policy == TP_POLICY_BASED_ON_FIXED_RR){
         tp = p + (p - sl) * Rr;
      }
      sl = NormalizeDouble(sl ,_Digits);
      tp = NormalizeDouble(tp, _Digits);
      double _Rr = (tp-p)/(p-sl);
      double lot_size = normalize_volume(calculate_lot_size((p-sl)/_Point, risk));
      
      if(enter_policy==ENTER_POLICY_INSTANT_ON_CANDLE_CLOSE) trade.Buy(lot_size, _Symbol, p, sl, tp, PositionComment);
      else if(enter_policy==ENTER_POLICY_PENDING_OEDRDER) trade.BuyLimit(lot_size, p, _Symbol, sl, tp, ORDER_TIME_GTC, 0, PositionComment);      
   
   }else if(trend[0]==2 && (bos[0]!=bos[1] || trend[0]!=trend[1]) && (!confirm_with_higher_timeframe || (higher_trend[0]==2 && confirm_with_higher_timeframe))){  // enter sell
      double p = 0;
      double broken_level[];
      ArraySetAsSeries(broken_level, true);
      CopyBuffer(ind_handle1, BROKEN_LEVEL_BUFFER, 1, 1, broken_level);
      if(enter_policy==ENTER_POLICY_INSTANT_ON_CANDLE_CLOSE) p = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      else if(enter_policy==ENTER_POLICY_PENDING_OEDRDER){
         DeleteAllOrders(trade);
         p = broken_level[0];
      }
      p = NormalizeDouble(p, _Digits);
      double sl = find_nearest_unbroken_peak_price(true, p);
      if(sl<0) return;
      if(MathAbs(broken_level[0]-sl)/_Point<valid_range_min_points) return;
      if(enter_policy==ENTER_POLICY_PENDING_OEDRDER) p += (sl-p)*pending_order_ratio;
      sl += (sl-broken_level[0])*sl_percent_offset/100;
      double tp;
      if(tp_policy == TP_POLICY_BASED_ON_PEAK){
         double mintp = p - (sl - p) * Rr;
         tp = find_nearest_unbroken_peak_price(false, 0, mintp);
         if(tp<0) return;
      }else if(tp_policy == TP_POLICY_BASED_ON_FIXED_RR){
         tp = p - (sl - p) * Rr;
      }
      sl = NormalizeDouble(sl ,_Digits);
      tp = NormalizeDouble(tp, _Digits);
      double _Rr = (p-tp)/(sl-p);
      double lot_size = normalize_volume(calculate_lot_size((sl-p)/_Point, risk));
      
      if(enter_policy==ENTER_POLICY_INSTANT_ON_CANDLE_CLOSE) trade.Sell(lot_size, _Symbol, p, sl, tp, PositionComment);
      else if(enter_policy==ENTER_POLICY_PENDING_OEDRDER) trade.SellLimit(lot_size, p, _Symbol, sl, tp, ORDER_TIME_GTC, 0, PositionComment);      
   }

}


double find_nearest_unbroken_peak_price(bool findtop, double higherthan=0, double lowerthan=100000000){
   double peaks[], broken[], high[], low[];
   ArraySetAsSeries(peaks, true);
   ArraySetAsSeries(broken, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   int ncandles = 500;
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

//double find_nearest_unbroken_peak_price_new(bool findtop, double higherthan=0, double lowerthan=100000000){
//   double high[], low[];
//   ArraySetAsSeries(high, true);
//   ArraySetAsSeries(low, true);
//   int ncandles = 100;
//   CopyBuffer(ind_handle1, HIGH_BUFFER, 1, ncandles, high);
//   CopyBuffer(ind_handle1, LOW_BUFFER, 1, ncandles, low);
//   double hi=0;
//   double lo=100000000;
//   int counter=0;
//   for(int i=0;i<ncandles;i++){
//      if(findtop){
//         if(high[i]>hi && high[i]>=higherthan && high[i]<=lowerthan){
//            hi = high[i];
//            counter = 0;
//         }else{
//            counter++;
//            if(counter==3) return hi;
//         }
//      }else{
//         if(low[i]<lo && low[i]>=higherthan && low[i]<=lowerthan){
//            lo = low[i];
//            counter = 0;
//         }else{
//            counter++;
//            if(counter==3) return lo;
//         }
//      }
//   }
//   return -1;   
//}


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
   return NormalizeDouble(100*result,0);   
}

void update_news(){
   static int last_day;
   MqlDateTime today;
   TimeToStruct(TimeCurrent(), today);
   if(last_day != today.day){
      last_day = today.day;
      today_news = CNews(0,0,country_name,important_news);
      ArrayPrint(today_news.news);
   }

}