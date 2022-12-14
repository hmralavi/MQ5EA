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

input group "Indicator settings"
input bool use_costume_timeframe = false;
input ENUM_TIMEFRAMES costume_timeframe = PERIOD_H1;
input bool confirm_with_higher_timeframe = true;
input ENUM_TIMEFRAMES higher_timeframe = PERIOD_D1;
input int n_candles_peak = 6;

input group "Entry settings"
input double sl_points_offset = 100;  // sl points offset from peak
input double Rr = 2;  // reward/risk ratio 
input double risk_percent = 2;  // risk percent

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
   ind_handle1 = iCustom(_Symbol, tf, "..\\Experts\\mq5ea\\indicators\\choch_detector.ex5", n_candles_peak);
   ind_handle2 = iCustom(_Symbol, higher_timeframe, "..\\Experts\\mq5ea\\indicators\\choch_detector.ex5", n_candles_peak);
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
   if(trend[0]!=trend[1]) CloseAllPositions(trade);
   
   if(trend[0]==1 && trend[1]==2 && (!confirm_with_higher_timeframe || (higher_trend[0]==1 && confirm_with_higher_timeframe))){  // enter buy
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double sl = find_nearest_peak_price(false) - sl_points_offset*_Point;
      double tp = ask + (ask-sl)*Rr;
      if(sl>ask) return;
      double lot_size = calculate_lot_size((ask-sl)/_Point, risk_percent);
      trade.Buy(lot_size, _Symbol, ask, sl, tp);
   
   }else if(trend[0]==2 && trend[1]==1 && (!confirm_with_higher_timeframe || (higher_trend[0]==2 && confirm_with_higher_timeframe))){  // enter sell
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double sl = find_nearest_peak_price(true) + sl_points_offset*_Point;
      double tp = bid - (sl-bid)*Rr;
      if(sl<bid) return;
      double lot_size = calculate_lot_size((sl-bid)/_Point, risk_percent);
      trade.Sell(lot_size, _Symbol, bid, sl, tp);      
   }

}


double calculate_lot_size(double slpoints, double risk_percent){
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskusd = risk_percent * balance / 100;
   double lot = riskusd/slpoints;
   lot = NormalizeDouble(lot, 2);
   return lot;
}


double find_nearest_peak_price(bool findtop){
   double peaks[], broken[], high[], low[];
   ArraySetAsSeries(peaks, true);
   ArraySetAsSeries(broken, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   int ncandles = 200;
   CopyBuffer(ind_handle1, PEAK_BUFFER, 1, ncandles, peaks);
   CopyBuffer(ind_handle1, PEAK_BROKEN_BUFFER, 1, ncandles, broken);
   CopyBuffer(ind_handle1, HIGH_BUFFER, 1, ncandles, high);
   CopyBuffer(ind_handle1, LOW_BUFFER, 1, ncandles, low);
   for(int i=0;i<ncandles;i++){
      if(peaks[i]==1 && broken[i]==0 && findtop) return high[i];
      if(peaks[i]==2 && broken[i]==0 && !findtop) return low[i];
   }
   return -1;   
}