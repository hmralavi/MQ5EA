#include <Trade/Trade.mqh>

enum ENUM_MARKET_TREND_TYPE{
   MARKET_TREND_NEUTRAL=0,
   MARKET_TREND_BULLISH=1,
   MARKET_TREND_BEARISH=2
};

enum ENUM_MONTH{
   MONTH_ALL=0, // All
   MONTH_JAN=1, // Jan
   MONTH_FEB=2, // Feb
   MONTH_MAR=3, // Mar
   MONTH_APR=4, // Apr
   MONTH_MAY=5, // May
   MONTH_JUN=6, // Jun
   MONTH_JUL=7, // Jul
   MONTH_AUG=8, // Aug
   MONTH_SEP=9, // Sep
   MONTH_OCT=10, // Oct
   MONTH_NOV=11, // Nov
   MONTH_DEC=12  // Dec
};

enum ENUM_WEEKDAY{
   WEEKDAY_ALL = 0, // All
   WEEKDAY_MON = 1, // Mon 
   WEEKDAY_TUE = 2, // Tue
   WEEKDAY_WED = 3, // Wed
   WEEKDAY_THU = 4, // Thu
   WEEKDAY_FRI = 5 // Fri
};

enum ENUM_CUSTOM_TIMEFRAMES{
   CUSTOM_TIMEFRAMES_M1 = 0,  // 1 Min
   CUSTOM_TIMEFRAMES_M5 = 1,  // 5 Min
   CUSTOM_TIMEFRAMES_M10 = 2,  // 10 Min
   CUSTOM_TIMEFRAMES_M15 = 3,   // 15 Min
   CUSTOM_TIMEFRAMES_M30 = 4,  // 30 Min
   CUSTOM_TIMEFRAMES_H1 = 5,  // 1 Hr
   CUSTOM_TIMEFRAMES_H4 = 6,  // 4 Hr
   CUSTOM_TIMEFRAMES_H6 = 7,  // 6 Hr
   CUSTOM_TIMEFRAMES_H12 = 8,  // 12 Hr      
   CUSTOM_TIMEFRAMES_D1 = 9,  // 1 Day
   CUSTOM_TIMEFRAMES_W1 = 10,  // 1 Week
   CUSTOM_TIMEFRAMES_MN1 = 11,  // 1 Month
};


ENUM_TIMEFRAMES convert_tf(ENUM_CUSTOM_TIMEFRAMES ctf){
   switch(ctf){
      case CUSTOM_TIMEFRAMES_M1:
         return PERIOD_M1;   
      case CUSTOM_TIMEFRAMES_M5:
         return PERIOD_M5;
      case CUSTOM_TIMEFRAMES_M10:
         return PERIOD_M10;
      case CUSTOM_TIMEFRAMES_M15:
         return PERIOD_M15;
      case CUSTOM_TIMEFRAMES_M30:
         return PERIOD_M30;
      case CUSTOM_TIMEFRAMES_H1:
         return PERIOD_H1;                  
      case CUSTOM_TIMEFRAMES_H4:
         return PERIOD_H4;
      case CUSTOM_TIMEFRAMES_H6:
         return PERIOD_H6;
      case CUSTOM_TIMEFRAMES_H12:
         return PERIOD_H12;
      case CUSTOM_TIMEFRAMES_D1:
         return PERIOD_D1;
      case CUSTOM_TIMEFRAMES_W1:
         return PERIOD_W1;  
      case CUSTOM_TIMEFRAMES_MN1:
         return PERIOD_MN1;                                  
      default:
         return 0;                  
   }
}


struct PeakProperties{
  MqlRates main_candle;
  int shift;
  bool isTop; 
};

struct OrderBlockProperties{
   MqlRates main_candle;
   PeakProperties broken_peak;
   int shift;
   bool isDemandZone;
   MqlRates touching_candles[];
   MqlRates breaking_candle;
   bool isBroken;
};

bool IsNewCandle(ENUM_TIMEFRAMES timeframe, int delay_seconds=0){
   datetime current_candle_time = iTime(_Symbol, timeframe, 0);
   static datetime lasttime = current_candle_time;
   if(lasttime == current_candle_time){
         return false;
   }else{
      if(TimeCurrent()-current_candle_time<delay_seconds) return false;
      lasttime = current_candle_time;
      return true;
   }
}

void GetMyPositionsTickets(long magic_number, ulong& pos_tickets[]){
   uint postotal = PositionsTotal();
   uint npos = 0;
   for(uint i=0; i<postotal; i++){
      string possymbol = PositionGetSymbol(i);
      long posmagic = PositionGetInteger(POSITION_MAGIC);
      if(possymbol==_Symbol && posmagic==magic_number){
         npos++;
         ArrayResize(pos_tickets, npos);
         pos_tickets[npos-1] = PositionGetTicket(i);
      }
   }
}

void GetMyOrdersTickets(long magic_number, ulong& order_tickets[]){
   uint orderstotal = OrdersTotal();
   uint nord = 0;
   for(uint i=0; i<orderstotal; i++){
      ulong ordticket = OrderGetTicket(i);
      OrderSelect(ordticket);
      string ordsymbol = OrderGetString(ORDER_SYMBOL);
      long ordmagic = OrderGetInteger(ORDER_MAGIC);
      if(ordsymbol==_Symbol && ordmagic==magic_number){
         nord++;
         ArrayResize(order_tickets, nord);
         order_tickets[nord-1] = ordticket;
      }
   }
}

void DeleteAllOrders(CTrade& trade_){
   ulong order_tickets[];
   GetMyOrdersTickets(trade_.RequestMagic(), order_tickets);
   int nords = ArraySize(order_tickets);
   for(int i=0; i<nords; i++) trade_.OrderDelete(order_tickets[i]);
}

void CloseAllPositions(CTrade& trade_, int which_positions_type=0){ // which_positions_type: 0:all, 1:buys only, 2:sell only
   ulong position_tickets[];
   GetMyPositionsTickets(trade_.RequestMagic(), position_tickets);
   int npos = ArraySize(position_tickets);
   for(int i=0; i<npos; i++){
      if(which_positions_type>0){
         PositionSelectByTicket(position_tickets[i]);
         ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         if(which_positions_type==1 && pos_type==POSITION_TYPE_BUY) trade_.PositionClose(position_tickets[i]);
         else if(which_positions_type==2 && pos_type==POSITION_TYPE_SELL) trade_.PositionClose(position_tickets[i]);
      }else if(which_positions_type==0){
         trade_.PositionClose(position_tickets[i]);
      }
   }
}

void RiskFree(CTrade& trade_, ulong pos_ticket){
   PositionSelectByTicket(pos_ticket);
   ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   string current_sym = PositionGetString(POSITION_SYMBOL);
   double current_sl = PositionGetDouble(POSITION_SL);
   double current_tp = PositionGetDouble(POSITION_TP);
   double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
   double ask_price = SymbolInfoDouble(current_sym, SYMBOL_ASK);
   double bid_price = SymbolInfoDouble(current_sym, SYMBOL_BID);
   bool new_sl = false;
   if(pos_type == POSITION_TYPE_BUY && bid_price - open_price >= open_price-current_sl && current_sl<open_price) new_sl = true;
   else if(pos_type == POSITION_TYPE_SELL && open_price - ask_price >= current_sl-open_price && current_sl>open_price) new_sl=true;
   if(new_sl) trade_.PositionModify(pos_ticket, open_price, current_tp);
}

void TrailingStoploss(CTrade& trade_, ulong pos_ticket, double slpoints, double trigger_points=0){
   PositionSelectByTicket(pos_ticket);
   ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   string current_sym = PositionGetString(POSITION_SYMBOL);
   double current_sl = PositionGetDouble(POSITION_SL);
   double current_tp = PositionGetDouble(POSITION_TP);
   double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
   double ask_price = SymbolInfoDouble(current_sym, SYMBOL_ASK);
   double bid_price = SymbolInfoDouble(current_sym, SYMBOL_BID);
   double new_sl = 0;
   if(pos_type == POSITION_TYPE_BUY){
      if(bid_price - open_price < trigger_points*_Point) return;
      new_sl = bid_price - slpoints * _Point;
      if(new_sl <= current_sl) return;
      if(new_sl < open_price) return;
   }else if(pos_type == POSITION_TYPE_SELL){
      if(open_price - ask_price < trigger_points*_Point) return;
      new_sl = ask_price + slpoints * _Point;
      if(new_sl >= current_sl) return;
      if(new_sl > open_price) return;
   }
   new_sl = NormalizeDouble(new_sl, _Digits);
   trade_.PositionModify(pos_ticket, new_sl, current_tp);
}

void DetectPeaks(PeakProperties& peaks[], ENUM_TIMEFRAMES timeframe,int start, int count, int ncandles_peak, bool weighted_peaks=true){
   MqlRates mrate[];
   ArraySetAsSeries(mrate, true);
   if(CopyRates(_Symbol,timeframe,start,count,mrate)<0){
      Alert(__FUNCTION__, "-->Error copying rates/history data - error:",GetLastError(),"!!");
      ResetLastError();
      return;
   }
   DetectPeaksCoreFunc(peaks, mrate, ncandles_peak, 0, -1, weighted_peaks);
}

void DetectPeaksCoreFunc(PeakProperties& peaks[], MqlRates& mrate[], int ncandles_peak, int start_candle=0, int end_candle=-1, bool weighted_peaks=true){
   if(end_candle==-1) end_candle=ArraySize(mrate);
   int npeaks = 0;
   bool _istop;
   bool _isbottom;
   for(int icandle=ncandles_peak+start_candle; icandle<end_candle-ncandles_peak; icandle++){
      _istop = true;
      _isbottom = true;
      for(int i=-ncandles_peak; i<=ncandles_peak; i++){
         if(i==0) continue;
         double w = weighted_peaks?1.0*MathSqrt(MathAbs(i))*_Point:0;
         _istop = _istop && (mrate[icandle].high >= mrate[icandle+i].high+w);// && (mrate[icandle].low>=mrate[icandle+i].low-1.0*MathSqrt(MathAbs(i))*_Point);
         _isbottom = _isbottom && (mrate[icandle].low <= mrate[icandle+i].low-w);// && (mrate[icandle].high<=mrate[icandle+i].high+1.0*MathSqrt(MathAbs(i))*_Point);
         if(!_istop && !_isbottom) break;
      }
      if(!_istop && !_isbottom) continue;
      npeaks++;
      ArrayResize(peaks, npeaks);
      peaks[npeaks-1].isTop = _istop;
      peaks[npeaks-1].main_candle = mrate[icandle];
      peaks[npeaks-1].shift = icandle;
      icandle += ncandles_peak-1;
   }

}

bool GetExtremumPeak(PeakProperties& extremum_peak, const PeakProperties& peaks[], bool findMax){
   int npeaks = ArraySize(peaks);
   bool success = false;
   for(int i=0;i<npeaks;i++){
      bool cond1 = findMax && peaks[i].isTop && (peaks[i].main_candle.high>extremum_peak.main_candle.high || !success);
      bool cond2 = !findMax && !peaks[i].isTop && (peaks[i].main_candle.low<extremum_peak.main_candle.low || !success);
      if(cond1 || cond2){
         extremum_peak = peaks[i];
         success = true;
      }
   }
   return success;
}

void PlotPeaks(PeakProperties& peaks[], int width=1){
   int npeaks = ArraySize(peaks);
   for(int i=0; i<npeaks; i++){
      string objname = peaks[i].isTop?"peak"+IntegerToString(i,3,'0')+"_top":"peak"+IntegerToString(i,3,'0')+"_bottom";
      ENUM_OBJECT objtype = peaks[i].isTop?OBJ_ARROW_DOWN:OBJ_ARROW_UP;
      color objclr = peaks[i].isTop?clrYellow:clrBlue;
      double value = peaks[i].isTop?peaks[i].main_candle.high+60*_Point:peaks[i].main_candle.low-10*_Point;
      ObjectCreate(0, objname, objtype, 0, peaks[i].main_candle.time, value);
      ObjectSetInteger(0, objname, OBJPROP_COLOR, objclr);
      ObjectSetInteger(0, objname, OBJPROP_WIDTH, width);
   }
}

ENUM_MARKET_TREND_TYPE DetectPeaksTrend(ENUM_TIMEFRAMES timeframe,int start, int count, int ncandles_peak, bool weighted_peaks=true){
   PeakProperties peaks[];
   DetectPeaks(peaks, timeframe, start, count, ncandles_peak, weighted_peaks);
   
   int npeaks = ArraySize(peaks);
   if(npeaks<4) return MARKET_TREND_NEUTRAL;
   if(!(peaks[0].isTop && !peaks[1].isTop && peaks[2].isTop && !peaks[3].isTop) && 
      !(!peaks[0].isTop && peaks[1].isTop && !peaks[2].isTop && peaks[3].isTop)) return MARKET_TREND_NEUTRAL;
   
   double bid_price = SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double h1,h2,l1,l2;
   if(peaks[0].isTop){
      h1 = peaks[0].main_candle.high;
      h2 = peaks[2].main_candle.high;
      l1 = peaks[1].main_candle.low;
      l2 = peaks[3].main_candle.low;
   }else{
      h1 = peaks[1].main_candle.high;
      h2 = peaks[3].main_candle.high;
      l1 = peaks[0].main_candle.low;
      l2 = peaks[2].main_candle.low;
   }
   if(h1>h2 && l1>l2 && h2>l1 && bid_price>l1) return MARKET_TREND_BULLISH;
   if(h1<h2 && l1<l2 && h1>l2 && bid_price<h1) return MARKET_TREND_BEARISH;
   return MARKET_TREND_NEUTRAL;
}

//--- detect orderblocks based on peaks and imbalancing candle
void DetectOrderBlocks(OrderBlockProperties& obs[], ENUM_TIMEFRAMES timeframe, int start, int count,
                       int ncandles_peak, bool must_form_fvg=false){
   MqlRates mrate[];
   ArraySetAsSeries(mrate, true);
   if(CopyRates(_Symbol,timeframe,start,count,mrate)<0){
      Alert(__FUNCTION__, "-->Error copying rates/history data - error:",GetLastError(),"!!");
      ResetLastError();
      return;
   }
   
   PeakProperties peaks[];
   DetectPeaks(peaks, timeframe, start, count, ncandles_peak);
   int npeaks = ArraySize(peaks);
   int nobs = 0;
   for(int ipeak=0;ipeak<npeaks;ipeak++){
      for(int icandle=peaks[ipeak].shift-1;icandle>=0;icandle--){
         //--- find the candle which breaks the peak
         if((peaks[ipeak].isTop && mrate[icandle].high>peaks[ipeak].main_candle.high) ||
            (!peaks[ipeak].isTop && mrate[icandle].low<peaks[ipeak].main_candle.low)){
            PeakProperties ob_peak;
            bool ob_found = false;
            //--- find the orderblock as the peak right before the breaking candle    
            for(int isearch_ob_peak=ipeak-1;isearch_ob_peak>=0;isearch_ob_peak--){
               if(peaks[isearch_ob_peak].shift<=icandle) break;                     
               if(peaks[isearch_ob_peak].isTop!=peaks[ipeak].isTop){
                  ob_peak = peaks[isearch_ob_peak];
                  ob_found = true;
               }
            }
            //--- if no ob was found, then consider ob as the last bullish/bearish candle right before the breakout.            
            if(!ob_found){               
               for(int iobcandle=icandle+1;iobcandle<peaks[ipeak].shift;iobcandle++){
                  if((peaks[ipeak].isTop && mrate[iobcandle].close<mrate[iobcandle].open && mrate[iobcandle].high<peaks[ipeak].main_candle.high) || 
                     (!peaks[ipeak].isTop && mrate[iobcandle].close>mrate[iobcandle].open && mrate[iobcandle].low>peaks[ipeak].main_candle.low)){
                     ob_peak.main_candle = mrate[iobcandle];
                     ob_peak.shift = iobcandle;
                     ob_peak.isTop = !peaks[ipeak].isTop;
                     ob_found = true;
                     break;
                  }
               }              
            }            
            
            if(!ob_found) break;             
            if(must_form_fvg){   
               if(ob_peak.shift<2){
                  ob_found = false;
               }else{           
                  if(!( (peaks[ipeak].isTop  && mrate[ob_peak.shift].high<mrate[ob_peak.shift-2].low && (mrate[ob_peak.shift-1].close-mrate[ob_peak.shift-1].open)/(mrate[ob_peak.shift-1].high-mrate[ob_peak.shift-1].low)>0.5) || 
                        (!peaks[ipeak].isTop && mrate[ob_peak.shift].low>mrate[ob_peak.shift-2].high && (mrate[ob_peak.shift-1].open-mrate[ob_peak.shift-1].close)/(mrate[ob_peak.shift-1].high-mrate[ob_peak.shift-1].low)>0.5) )){
                     ob_found = false;
                  }
               }
            }   
            if(!ob_found) break;
            nobs++;
            ArrayResize(obs, nobs);
            obs[nobs-1].main_candle = ob_peak.main_candle;
            obs[nobs-1].broken_peak = peaks[ipeak];
            obs[nobs-1].shift = ob_peak.shift;
            obs[nobs-1].isDemandZone = !ob_peak.isTop;
            obs[nobs-1].isBroken = false;
            //--- find touches or break of the orderblock zone.  
            int ntouches = 0;
            double ob_low;
            double ob_high;
            GetOrderBlockZone(obs[nobs-1], ob_low, ob_high);
            for(int itouching=icandle-1;itouching>=0;itouching--){
               if((ob_peak.isTop && mrate[itouching].high>=ob_low && mrate[itouching].high<=ob_high) ||
                  (!ob_peak.isTop && mrate[itouching].low<=ob_high && mrate[itouching].low>=ob_low)){
                  ntouches++;
                  ArrayResize(obs[nobs-1].touching_candles, ntouches);
                  obs[nobs-1].touching_candles[ntouches-1] = mrate[itouching];
               }else if((ob_peak.isTop && mrate[itouching].high>ob_high) ||
                        (!ob_peak.isTop && mrate[itouching].low<ob_low)){
                  obs[nobs-1].breaking_candle = mrate[itouching];
                  obs[nobs-1].isBroken = true;
                  break;
               }
            }
            break;
         }
      }
   }
}

void GetOrderBlockZone(OrderBlockProperties& ob_candle, double& low_level, double& high_level){
   low_level = ob_candle.isDemandZone?ob_candle.main_candle.low:MathMin(ob_candle.main_candle.open,ob_candle.main_candle.close);
   high_level = ob_candle.isDemandZone?MathMax(ob_candle.main_candle.open,ob_candle.main_candle.close):ob_candle.main_candle.high;
   //low_level = ob_candle.main_candle.low;
   //high_level = ob_candle.main_candle.high;
}

void PlotOrderBlocks(OrderBlockProperties& obs[],string name_prefix="", ENUM_LINE_STYLE line_style=STYLE_SOLID, int width=1 ,bool fill=false, int nMax=-1){
   int nob = ArraySize(obs);
   nMax = MathMin(nMax, nob);
   if(nMax==-1) nMax=nob;
   for(int iob=0;iob<nMax;iob++){
      string objname = obs[iob].isDemandZone?"ob"+IntegerToString(iob,3,'0')+"_demand":"ob"+IntegerToString(iob,3,'0')+"_supply";
      if(name_prefix!="") objname = name_prefix + "_" + objname;
      ENUM_OBJECT objtype = OBJ_RECTANGLE;
      color objclr = obs[iob].isDemandZone?clrGreen:clrRed;
      datetime endtime = obs[iob].isBroken?obs[iob].breaking_candle.time:iTime(_Symbol,PERIOD_CURRENT,0);
      double low_level;
      double high_level;
      GetOrderBlockZone(obs[iob], low_level, high_level);
      ObjectCreate(0, objname, objtype, 0, endtime, high_level, obs[iob].main_candle.time, low_level);
      ObjectSetInteger(0, objname, OBJPROP_COLOR, objclr);  
      ObjectSetInteger(0, objname, OBJPROP_STYLE, line_style);
      ObjectSetInteger(0, objname, OBJPROP_WIDTH, width);
      ObjectSetInteger(0, objname, OBJPROP_FILL, fill);
   }
}

bool is_session_time_allowed(string session_start_time, string session_end_time){
   datetime   _start = StringToTime(session_start_time);
   datetime   _finish = StringToTime(session_end_time);
   datetime _currentservertime = TimeCurrent();
   return _currentservertime>=_start && _currentservertime<=_finish;
}

bool is_session_time_allowed_int(int _session_start_hour, int _session_end_hour){
   datetime currentservertime = TimeCurrent();
   MqlDateTime timestruct;
   TimeToStruct(currentservertime, timestruct);
   return timestruct.hour>=_session_start_hour && timestruct.hour<=_session_end_hour;
}

bool is_session_time_allowed_double(double _session_start_hour, double _session_end_hour){
   MqlDateTime stime, etime;
   datetime datetime_start, datetime_end;
   datetime currentservertime = TimeCurrent();
   TimeToStruct(currentservertime, stime);
   TimeToStruct(currentservertime, etime);
   stime.hour = (int)floor(_session_start_hour);
   stime.min = (int)(_session_start_hour-stime.hour)*60;
   stime.sec = 0;
   etime.hour = (int)floor(_session_end_hour);
   etime.min = (int)(_session_end_hour-etime.hour)*60;
   etime.sec = 0;
   datetime_start = StructToTime(stime);
   datetime_end = StructToTime(etime);
   return currentservertime>=datetime_start && currentservertime<=datetime_end;
}

double calculate_lot_size(double slpoints, double riskusd){
   double multiplier = 1;
   if(_Symbol=="XAUUSD" || _Symbol=="XAGUSD") multiplier = 10;
   double tick_val = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   if(tick_val*slpoints==0) return 0;
   double lot = riskusd/(tick_val*multiplier*slpoints);
   return lot;
}

double normalize_volume(const double lot_){
   int ndigits = get_number_digits(SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP));
   double lot = lot_;
   lot = floor(lot*pow(10, ndigits))/pow(10, ndigits);
   lot = NormalizeDouble(lot, ndigits);
   return lot;    
}


int get_number_digits(const double number){
   double num=number;
   int count=0;
   for(;count<8;count++) {
      if(!((int)num-num))
         return(count);
      num*=10; }
   return(count);
}

double get_average_spread(){
   MqlRates rates[];
   int n = 10;
   CopyRates(_Symbol, PERIOD_M1, 0, n, rates);
   double spread = 0;
   for(int i=0;i<n;i++){
      spread += rates[i].spread;
   }
   spread /= n;
   spread = round(spread)*_Point;
   return spread;
}

double calculate_today_profit(int magic_number){
   MqlDateTime time_start, time_end;
   TimeToStruct(TimeCurrent(), time_start);
   TimeToStruct(TimeCurrent(), time_end);
   time_start.hour=0;
   time_start.min=0;
   time_start.sec=0;
   time_end.hour=23;
   time_end.min=59;
   time_end.sec=59;

   datetime datetime_start = StructToTime(time_start);
   datetime datetime_end = StructToTime(time_end);

   double prof = 0;
   HistorySelect(datetime_start, datetime_end);
   int ndeals = HistoryDealsTotal();
   for(int i=0;i<ndeals;i++){
      ulong dealticket = HistoryDealGetTicket(i);
      int magic = (int)HistoryDealGetInteger(dealticket, DEAL_MAGIC);
      if(magic != magic_number) continue;
      prof += HistoryDealGetDouble(dealticket, DEAL_PROFIT) + HistoryDealGetDouble(dealticket, DEAL_COMMISSION) + HistoryDealGetDouble(dealticket, DEAL_FEE) + HistoryDealGetDouble(dealticket, DEAL_SWAP);
   }
   ulong pos_tickets[];
   GetMyPositionsTickets(magic_number, pos_tickets);
   int npos = ArraySize(pos_tickets);
   for(int ipos=0;ipos<npos;ipos++){
      PositionSelectByTicket(pos_tickets[ipos]);
      prof += PositionGetDouble(POSITION_PROFIT);
   }
   return prof;
}

void calculate_all_trades_profit_drawdown(int magic_number, double& profit, double& drawdown){
   MqlDateTime time_start, time_end;
   TimeToStruct(TimeCurrent(), time_start);
   TimeToStruct(TimeCurrent(), time_end);
   time_start.day = 1;
   time_start.mon = 1;
   time_start.year = 2000;
   time_start.hour = 0;
   time_start.min = 0;
   time_start.sec = 0;
   time_end.day = 1;
   time_end.mon = 1;
   time_end.year = 2030;
   time_end.hour = 0;
   time_end.min = 0;
   time_end.sec = 0;

   datetime datetime_start = StructToTime(time_start);
   datetime datetime_end = StructToTime(time_end);

   double prof = 0;
   double dd = 0;
   HistorySelect(datetime_start, datetime_end);
   int ndeals = HistoryDealsTotal();
   for(int i=0;i<ndeals;i++){
      ulong dealticket = HistoryDealGetTicket(i);
      int magic = (int)HistoryDealGetInteger(dealticket, DEAL_MAGIC);
      if(magic != magic_number) continue;
      prof += HistoryDealGetDouble(dealticket, DEAL_PROFIT) + HistoryDealGetDouble(dealticket, DEAL_COMMISSION) + HistoryDealGetDouble(dealticket, DEAL_FEE) + HistoryDealGetDouble(dealticket, DEAL_SWAP);
      dd = MathMin(dd, prof);
   }
   ulong pos_tickets[];
   GetMyPositionsTickets(magic_number, pos_tickets);
   int npos = ArraySize(pos_tickets);
   for(int ipos=0;ipos<npos;ipos++){
      PositionSelectByTicket(pos_tickets[ipos]);
      prof += PositionGetDouble(POSITION_PROFIT);
      dd = MathMin(dd, prof);
   }
   profit = prof;
   drawdown = dd;
}