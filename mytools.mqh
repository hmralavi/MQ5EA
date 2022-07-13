#include <Trade/Trade.mqh>

enum ENUM_MARKET_TREND_TYPE{
   MARKET_TREND_NEUTRAL=0,
   MARKET_TREND_BULLISH=1,
   MARKET_TREND_BEARISH=2
};

struct PeakProperties{
  MqlRates main_candle;
  int shift;
  bool isTop; 
};

struct OrderBlockProperties{
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

void DetectPeaks(PeakProperties& peaks[], ENUM_TIMEFRAMES timeframe,int start, int count, int ncandles_peak){
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
      if(!_istop && !_isbottom) continue;
      npeaks++;
      ArrayResize(peaks, npeaks);
      peaks[npeaks-1].isTop = _istop;
      peaks[npeaks-1].main_candle = mrate[icandle];
      peaks[npeaks-1].shift = icandle;
      icandle += 2;
   }
}

void PlotPeaks(PeakProperties& peaks[]){
   int npeaks = ArraySize(peaks);
   for(int i=0; i<npeaks; i++){
      string objname = peaks[i].isTop?"peak"+IntegerToString(i,3,'0')+"_top":"peak"+IntegerToString(i,3,'0')+"_bottom";
      ENUM_OBJECT objtype = peaks[i].isTop?OBJ_ARROW_DOWN:OBJ_ARROW_UP;
      color objclr = peaks[i].isTop?clrBlack:clrBlue;
      double value = peaks[i].isTop?peaks[i].main_candle.high:peaks[i].main_candle.low;
      ObjectCreate(0, objname, objtype, 0, peaks[i].main_candle.time, value);
      ObjectSetInteger(0, objname, OBJPROP_COLOR, objclr);
      ObjectSetString(0, objname,OBJPROP_NAME,objname);
   }
}

ENUM_MARKET_TREND_TYPE DetectPeaksTrend(ENUM_TIMEFRAMES timeframe,int start, int count, int ncandles_peak){
   PeakProperties peaks[];
   DetectPeaks(peaks, timeframe, start, count, ncandles_peak);
   PlotPeaks(peaks);
   
   double tops[];
   double bottoms[];
   int ntops = 0;
   int nbottoms = 0;
   int npeaks = ArraySize(peaks);
   
   for(int i=0; i<npeaks; i++){
      if(peaks[i].isTop){
         ntops++;
         ArrayResize(tops, ntops);
         tops[ntops-1] = peaks[i].main_candle.high;
      }else{
         nbottoms++;
         ArrayResize(bottoms, nbottoms);
         bottoms[nbottoms-1] = peaks[i].main_candle.low;   
      }
   }
   
   double bid_price = SymbolInfoDouble(_Symbol,SYMBOL_BID);
   if(tops[0]>tops[1] && bottoms[0]>bottoms[1] && bid_price>bottoms[0]) return MARKET_TREND_BULLISH;
   if(tops[0]<tops[1] && bottoms[0]<bottoms[1] && bid_price<tops[0]) return MARKET_TREND_BEARISH;
   return MARKET_TREND_NEUTRAL;
}

void DetectOrderBlocks(OrderBlockProperties& obs[], ENUM_TIMEFRAMES timeframe, int start, int count, int ncandles_peak){
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
         if(peaks[ipeak].isTop){
            if(mrate[icandle].high>peaks[ipeak].main_candle.high && mrate[icandle].close>mrate[icandle].open){
               for(int iobcandle=icandle+1;iobcandle<peaks[ipeak].shift;iobcandle++){
                  if(mrate[iobcandle].close<mrate[iobcandle].open && mrate[iobcandle].high<peaks[ipeak].main_candle.high){
                     nobs++;
                     ArrayResize(obs, nobs);
                     obs[nobs-1].main_candle = mrate[iobcandle];
                     obs[nobs-1].shift = iobcandle;
                     obs[nobs-1].isDemandZone = true;
                     obs[nobs-1].breaking_candle.low = 0; // this means the breaking candle is not detected yet
                     int ntouches = 0;
                     for(int itouching=iobcandle-ncandles_peak;itouching>=0;itouching--){
                        if(mrate[itouching].low<obs[nobs-1].main_candle.high && mrate[itouching].low>obs[nobs-1].main_candle.low){
                           ntouches++;
                           ArrayResize(obs[nobs-1].touching_candles, ntouches);
                           obs[nobs-1].touching_candles[ntouches-1] = mrate[itouching];
                        }else if(mrate[itouching].low<obs[nobs-1].main_candle.low){
                           obs[nobs-1].breaking_candle = mrate[itouching];
                           break;
                        }
                     }
                     break;
                  }
               }  
               break;             
            }
         }else{
            if(mrate[icandle].low<peaks[ipeak].main_candle.low && mrate[icandle].close<mrate[icandle].open){
               for(int iobcandle=icandle+1;iobcandle<peaks[ipeak].shift;iobcandle++){
                  if(mrate[iobcandle].close>mrate[iobcandle].open && mrate[iobcandle].low>peaks[ipeak].main_candle.low){
                     nobs++;
                     ArrayResize(obs, nobs);
                     obs[nobs-1].main_candle = mrate[iobcandle];
                     obs[nobs-1].shift = iobcandle;
                     obs[nobs-1].isDemandZone = false;
                     obs[nobs-1].breaking_candle.low = 0;
                     int ntouches = 0;
                     for(int itouching=iobcandle-ncandles_peak;itouching>=0;itouching--){
                        if(mrate[itouching].high>obs[nobs-1].main_candle.low && mrate[itouching].high<obs[nobs-1].main_candle.high){
                           ntouches++;
                           ArrayResize(obs[nobs-1].touching_candles, ntouches);
                           obs[nobs-1].touching_candles[ntouches-1] = mrate[itouching];
                        }else if(mrate[itouching].high>obs[nobs-1].main_candle.high){
                           obs[nobs-1].breaking_candle = mrate[itouching];
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

void PlotOrderBlocks(OrderBlockProperties& obs[],string name_prefix="", ENUM_LINE_STYLE line_style=STYLE_SOLID, bool fill=false){
   int nob = ArraySize(obs);
   for(int iob=0;iob<nob;iob++){
      string objname = obs[iob].isDemandZone?"ob"+IntegerToString(iob,3,'0')+"_demand":"ob"+IntegerToString(iob,3,'0')+"_supply";
      if(name_prefix!="") objname = name_prefix + "_" + objname;
      ENUM_OBJECT objtype = OBJ_RECTANGLE;
      color objclr = obs[iob].isDemandZone?clrGreen:clrRed;
      datetime endtime = obs[iob].breaking_candle.low==0?iTime(_Symbol,PERIOD_CURRENT,0):obs[iob].breaking_candle.time;
      ObjectCreate(0, objname, objtype, 0, endtime, obs[iob].main_candle.high, obs[iob].main_candle.time, obs[iob].main_candle.low);
      ObjectSetInteger(0, objname, OBJPROP_COLOR, objclr);  
      ObjectSetInteger(0, objname, OBJPROP_STYLE, line_style);
      ObjectSetInteger(0, objname, OBJPROP_FILL, fill);
   }
}