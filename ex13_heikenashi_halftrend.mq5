/*
TODO:
*/

#include <../Experts/mq5ea/mytools.mqh>

input int ma_period = 200;
input int amplitude = 3;
input double channel_deviation = 2.0;
input double risk_per_trade = 0.01;  // of account balance
input double rr_factor = 2;
input bool trade_only_in_session_time = false;
input string session_start_time = "09:00";      // session start (server time)
input string session_end_time = "19:00";        // session end (server time)    
input int Magic = 130;

CTrade trade;
int heiken_ashi_handle;
double hac[], ma[], up[], down[], atr[];
double sl, tp1, tp2, entry_price;

#define HAC_BUFFER 3
#define MA_BUFFER 5
#define UP_BUFFER 7
#define DOWN_BUFFER 9
#define ATR_BUFFER 11

int OnInit(){  
   trade.SetExpertMagicNumber(Magic);
   heiken_ashi_handle = iCustom(_Symbol, _Period, "..\\Experts\\mq5ea\\indicators\\heiken_ashi_ema_halftrend.ex5", true, MODE_EMA, ma_period, amplitude, 100, channel_deviation);
   ObjectsDeleteAll(0);
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason){
   IndicatorRelease(heiken_ashi_handle);
}

void OnTick(){  
   if(!IsNewCandle(_Period)) return;
   if(!is_session_time_allowed(session_start_time, session_end_time) && trade_only_in_session_time) return;   
   ulong pos_tickets[];
   GetMyPositionsTickets(Magic, pos_tickets);
   if(ArraySize(pos_tickets)>0) return;
   CopyBuffer(heiken_ashi_handle, HAC_BUFFER, 1, 2, hac);
   CopyBuffer(heiken_ashi_handle, MA_BUFFER, 1, 2, ma);
   CopyBuffer(heiken_ashi_handle, UP_BUFFER, 1, 2, up);
   CopyBuffer(heiken_ashi_handle, DOWN_BUFFER, 1, 2, down);
   CopyBuffer(heiken_ashi_handle, ATR_BUFFER, 1, 2, atr);
   ArrayReverse(hac, 0, WHOLE_ARRAY);
   ArrayReverse(ma, 0, WHOLE_ARRAY);
   ArrayReverse(up, 0, WHOLE_ARRAY);
   ArrayReverse(down, 0, WHOLE_ARRAY);
   ArrayReverse(atr, 0, WHOLE_ARRAY);
   
   if(up[0]>0 && down[0]<down[1] && hac[0]>ma[0]){  // buy
      entry_price = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
      sl = NormalizeDouble(atr[0], _Digits);
      tp1 = NormalizeDouble(entry_price + (entry_price-sl)*rr_factor/2, _Digits);
      tp2 = NormalizeDouble(entry_price + (entry_price-sl)*rr_factor, _Digits);
      double lot = calculate_lot_size((entry_price-sl)/_Point, risk_per_trade);
      trade.Buy(lot/2, _Symbol, entry_price, sl, tp1);
      trade.Buy(lot/2, _Symbol, entry_price, sl, tp2);
   }else if(down[0]>0 && up[0]<up[1] && hac[0]<ma[0]){  // sell
      entry_price = SymbolInfoDouble(_Symbol,SYMBOL_BID);
      sl = NormalizeDouble(atr[0], _Digits);
      tp1 = NormalizeDouble(entry_price - (sl-entry_price)*rr_factor/2, _Digits);
      tp2 = NormalizeDouble(entry_price - (sl-entry_price)*rr_factor, _Digits);
      double lot = calculate_lot_size((sl-entry_price)/_Point, risk_per_trade);
      trade.Sell(lot/2, _Symbol, entry_price, sl, tp1);
      trade.Sell(lot/2, _Symbol, entry_price, sl, tp2);
   }
}

void OnTradeTransaction(const MqlTradeTransaction& trans,
                        const MqlTradeRequest& request,
                        const MqlTradeResult& result){

   if(trans.type == TRADE_TRANSACTION_DEAL_ADD){
      CDealInfo deal;
      deal.Ticket(trans.deal);
      HistorySelect(TimeCurrent()-PeriodSeconds(PERIOD_D1), TimeCurrent()+10);
      if(deal.Magic()==Magic && deal.Symbol()==_Symbol){
         if(deal.Entry()==DEAL_ENTRY_OUT){
            if(deal.Profit()>=0){
               ulong pos_tickets[];
               GetMyPositionsTickets(Magic, pos_tickets);
               if(ArraySize(pos_tickets)>0) trade.PositionModify(pos_tickets[0], entry_price, tp2);
            }
         }
      }
   }
}

double calculate_lot_size(double slpoints, double risk){
   return 0.1;
}