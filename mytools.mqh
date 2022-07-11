#include <Trade/Trade.mqh>

bool IsNewCandle(){
   datetime current_candle_time = iTime(_Symbol, _Period, 0);
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

void DetectPeaks(double& levels[], datetime& times[], bool& isTop[], int start, int count, int ncandles_peak){
   MqlRates mrate[];
   ArraySetAsSeries(mrate, true);
   if(CopyRates(_Symbol,_Period,start,count,mrate)<0){
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
         ArrayResize(isTop, npeaks);
         levels[npeaks-1] = mrate[icandle].high;
         times[npeaks-1] = mrate[icandle].time;
         isTop[npeaks-1] = true;
      }else if(_isbottom){
         npeaks++;
         ArrayResize(levels, npeaks);
         ArrayResize(times, npeaks);
         ArrayResize(isTop, npeaks);
         levels[npeaks-1] = mrate[icandle].low;
         times[npeaks-1] = mrate[icandle].time;
         isTop[npeaks-1] = false;
      }
   }
   

}

void PlotPeaks(double& levels[], datetime& times[], bool& isTop[]){
   int npeaks = ArraySize(levels);
   for(int i=0; i<npeaks; i++){
      string objname = isTop[i]?"top"+i:"bottom"+i;
      ENUM_OBJECT objtype = isTop[i]?OBJ_ARROW_DOWN:OBJ_ARROW_UP;
      color objclr = isTop[i]?clrBlack:clrBlue;
      ObjectCreate(0, objname, objtype, 0, times[i], levels[i]);
      ObjectSetInteger(0, objname, OBJPROP_COLOR, objclr);
   }
}