#include <Trade/Trade.mqh>

enum ENUM_MARKET_TREND_TYPE{
   MARKET_TREND_NEUTRAL=0,
   MARKET_TREND_BULLISH=1,
   MARKET_TREND_BEARISH=2
};

struct PeaksProperties{
  MqlRates main_candle;
  int shift;
  bool isTop; 
};

struct OrderBlocksProperties{
   MqlRates main_candle;
   int shift;
   bool isDemandZone;
   MqlRates touching_candles[];
   MqlRates breaking_candle;
};

bool IsNewCandle(ENUM_TIMEFRAMES timeframe){
   datetime current_candle_time = iTime(_Symbol, timeframe, 0);
   static datetime lasttime = current_candle_time;
   if(lasttime == current_candle_time){
         return false;
      }else{
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

void DeleteAllOrders(CTrade& trade){
   ulong order_tickets[];
   GetMyOrdersTickets(trade.RequestMagic(), order_tickets);
   int nords = ArraySize(order_tickets);
   for(uint i=0; i<nords; i++) trade.OrderDelete(order_tickets[i]);
}

void TrailingStoploss(CTrade& trade, ulong pos_ticket, double slpoints, double trigger_points=0){
   PositionSelectByTicket(pos_ticket);
   ENUM_POSITION_TYPE pos_type = PositionGetInteger(POSITION_TYPE);
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
      if(new_sl < current_sl) return;
   }else if(pos_type == POSITION_TYPE_SELL){
      if(open_price - ask_price < trigger_points*_Point) return;
      new_sl = ask_price + slpoints * _Point;
      if(new_sl > current_sl) return;
   }
   new_sl = NormalizeDouble(new_sl, _Digits);
   trade.PositionModify(pos_ticket, new_sl, current_tp);
}

void DetectPeaks(double& levels[], datetime& times[], int& shifts[], bool& isTop[], ENUM_TIMEFRAMES timeframe,int start, int count, int ncandles_peak){
   MqlRates mrate[];
   ArraySetAsSeries(mrate, true);
   if(CopyRates(_Symbol,timeframe,start,count,mrate)<0){
      Alert(__FUNCTION__, "-->Error copying rates/history data - error:",GetLastError(),"!!");
      ResetLastError();
      return;
   }
   uint npeaks = 0;
   bool _istop;
   bool _isbottom;
   for(int icandle=ncandles_peak; icandle<count-ncandles_peak; icandle++){
      _istop = true;
      _isbottom = true;
      for(int i=-ncandles_peak; i<=ncandles_peak; i++){
         _istop = _istop && (mrate[icandle].high >= mrate[icandle+i].high);
         _isbottom = _isbottom && (mrate[icandle].low <= mrate[icandle+i].low);
         if(!_istop && !_isbottom) break;
      }
      if(_istop){
         npeaks++;
         ArrayResize(levels, npeaks);
         ArrayResize(times, npeaks);
         ArrayResize(shifts, npeaks);
         ArrayResize(isTop, npeaks);
         levels[npeaks-1] = mrate[icandle].high;
         times[npeaks-1] = mrate[icandle].time;
         shifts[npeaks-1] = icandle;
         isTop[npeaks-1] = true;
         icandle += 2;
      }else if(_isbottom){
         npeaks++;
         ArrayResize(levels, npeaks);
         ArrayResize(times, npeaks);
         ArrayResize(shifts, npeaks);
         ArrayResize(isTop, npeaks);
         levels[npeaks-1] = mrate[icandle].low;
         times[npeaks-1] = mrate[icandle].time;
         shifts[npeaks-1] = icandle;
         isTop[npeaks-1] = false;
         icandle += 2;
      }
   }
}

void PlotPeaks(double& levels[], datetime& times[], bool& isTop[]){
   int npeaks = ArraySize(levels);
   for(int i=0; i<npeaks; i++){
      string objname = isTop[i]?"peak"+IntegerToString(i,3,'0')+"_top":"peak"+IntegerToString(i,3,'0')+"_bottom";
      ENUM_OBJECT objtype = isTop[i]?OBJ_ARROW_DOWN:OBJ_ARROW_UP;
      color objclr = isTop[i]?clrBlack:clrBlue;
      ObjectCreate(0, objname, objtype, 0, times[i], levels[i]);
      ObjectSetInteger(0, objname, OBJPROP_COLOR, objclr);
      ObjectSetString(0, objname,OBJPROP_NAME,objname);
   }
}

ENUM_MARKET_TREND_TYPE DetectPeaksTrend(ENUM_TIMEFRAMES timeframe,int start, int count, int ncandles_peak){
   double levels[];
   datetime times[];
   int shifts[];
   bool isTop[];
   DetectPeaks(levels, times, shifts, isTop, timeframe, start, count, ncandles_peak);
   PlotPeaks(levels, times, isTop);
   
   double tops[];
   double bottoms[];
   int ntops = 0;
   int nbottoms = 0;
   int npeaks = ArraySize(levels);
   
   for(int i=0; i<npeaks; i++){
      if(isTop[i]){
         ntops++;
         ArrayResize(tops, ntops);
         tops[ntops-1] = levels[i];
      }else{
         nbottoms++;
         ArrayResize(bottoms, nbottoms);
         bottoms[nbottoms-1] = levels[i];   
      }
   }
   
   double bid_price = SymbolInfoDouble(_Symbol,SYMBOL_BID);
   if(tops[0]>tops[1] && bottoms[0]>bottoms[1] && bid_price>bottoms[0]) return MARKET_TREND_BULLISH;
   if(tops[0]<tops[1] && bottoms[0]<bottoms[1] && bid_price<tops[0]) return MARKET_TREND_BEARISH;
   return MARKET_TREND_NEUTRAL;
}

void DetectOrderBlocks(double& zones[][2], datetime& times[][2], int& shifts[][2], bool& isDemandZone[], bool& isMitigated[],
                       ENUM_TIMEFRAMES timeframe, int start, int count, int ncandles_peak){
   MqlRates mrate[];
   ArraySetAsSeries(mrate, true);
   if(CopyRates(_Symbol,timeframe,start,count,mrate)<0){
      Alert(__FUNCTION__, "-->Error copying rates/history data - error:",GetLastError(),"!!");
      ResetLastError();
      return;
   }
   
   double peak_levels[];
   datetime peak_times[];
   int peak_shifts[];
   bool peak_isTop[];
   DetectPeaks(peak_levels, peak_times, peak_shifts, peak_isTop, timeframe, start, count, ncandles_peak);
   int npeaks = ArraySize(peak_levels);
   
   int nob = 0;
   for(int ipeak=0;ipeak<npeaks;ipeak++){
      for(int icandle=peak_shifts[ipeak]-1;icandle>=0;icandle--){
         if(peak_isTop[ipeak]){
            if(mrate[icandle].high>peak_levels[ipeak] && mrate[icandle].close>mrate[icandle].open){
               for(int iobcandle=icandle+1;iobcandle<peak_shifts[ipeak];iobcandle++){
                  if(mrate[iobcandle].close<mrate[iobcandle].open && mrate[iobcandle].high<peak_levels[ipeak]){
                     nob++;
                     ArrayResize(zones, nob);
                     ArrayResize(times, nob);
                     ArrayResize(shifts, nob);
                     ArrayResize(isDemandZone, nob);
                     ArrayResize(isMitigated, nob);
                     zones[nob-1][0] = mrate[iobcandle].low;
                     zones[nob-1][1] = mrate[iobcandle].high;
                     times[nob-1][0] = mrate[iobcandle].time;
                     shifts[nob-1][0] = iobcandle;
                     isDemandZone[nob-1] = true;
                     isMitigated[nob-1] = false;
                     for(int imitigation=iobcandle-ncandles_peak;imitigation>=0;imitigation--){
                        if(mrate[imitigation].low<zones[nob-1][1]){
                           times[nob-1][1] = mrate[imitigation].time;
                           shifts[nob-1][1] = imitigation;
                           isMitigated[nob-1] = true;
                           break;
                        }
                     }
                     break;
                  }
               }  
               break;             
            }
         }else{
            if(mrate[icandle].low<peak_levels[ipeak] && mrate[icandle].close<mrate[icandle].open){
               for(int iobcandle=icandle+1;iobcandle<peak_shifts[ipeak];iobcandle++){
                  if(mrate[iobcandle].close>mrate[iobcandle].open && mrate[iobcandle].low>peak_levels[ipeak]){
                     nob++;
                     ArrayResize(zones, nob);
                     ArrayResize(times, nob);
                     ArrayResize(shifts, nob);
                     ArrayResize(isDemandZone, nob);
                     ArrayResize(isMitigated, nob);
                     zones[nob-1][0] = mrate[iobcandle].low;
                     zones[nob-1][1] = mrate[iobcandle].high;
                     times[nob-1][0] = mrate[iobcandle].time;
                     shifts[nob-1][0] = iobcandle;
                     isDemandZone[nob-1] = false;
                     isMitigated[nob-1] = false;
                     for(int imitigation=iobcandle-ncandles_peak;imitigation>=0;imitigation--){
                        if(mrate[imitigation].high>zones[nob-1][0]){
                           times[nob-1][1] = mrate[imitigation].time;
                           shifts[nob-1][1] = imitigation;
                           isMitigated[nob-1] = true;
                           break;
                        }
                     }
                     break;
                  }
               }  
               break;             
            }         
         }
      }
   }                        
}

void PlotOrderBlocks(double& zones[][2], datetime& times[][2], bool& isDemandZone[], bool& isMitigated[],string name_prefix="", ENUM_LINE_STYLE line_style=STYLE_SOLID){
   int nob = ArraySize(isDemandZone);
   for(int iob=0;iob<nob;iob++){
      string objname = isDemandZone[iob]?"ob"+IntegerToString(iob,3,'0')+"_demand":"ob"+IntegerToString(iob,3,'0')+"_supply";
      if(name_prefix!="") objname = name_prefix + "_" + objname;
      ENUM_OBJECT objtype = OBJ_RECTANGLE;
      color objclr = isDemandZone[iob]?clrGreen:clrRed;
      datetime endtime = isMitigated[iob]?times[iob][1]:iTime(_Symbol,PERIOD_CURRENT,0);
      ObjectCreate(0, objname, objtype, 0, endtime, zones[iob][1], times[iob][0], zones[iob][0]);
      ObjectSetInteger(0, objname, OBJPROP_COLOR, objclr);  
      ObjectSetInteger(0, objname, OBJPROP_STYLE, line_style);
      ObjectSetInteger(0, objname, OBJPROP_FILL, false);
   }
}