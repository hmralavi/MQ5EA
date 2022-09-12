/*
TODO:
   position volume risk management for other forex pairs.
*/

#include <../Experts/mq5ea/mytools.mqh>

input int ma_period = 200;
input int amplitude = 3;
input int atr_period = 14;
input double atr_channel_deviation = 2.0;
input double risk_per_trade = 0.01;  // risk
input double rr_factor = 2;
input bool trade_only_in_session_time = false;
input string session_start_time = "09:00";      // session start (server time)
input string session_end_time = "19:00";        // session end (server time)    
input int Magic = 130;

CTrade trade;
int heiken_ashi_handle;
double hao[], hac[], ma[], updown[], atr[];
double sl, tp1, tp2, entry_price;

#define HAO_BUFFER 0
#define HAC_BUFFER 3
#define MA_BUFFER 5
#define UPDOWN_BUFFER 8
#define ATR_BUFFER 9

int OnInit(){  
   trade.SetExpertMagicNumber(Magic);
   heiken_ashi_handle = iCustom(_Symbol, _Period, "..\\Experts\\mq5ea\\indicators\\heiken_ashi_ema_halftrend.ex5", true, MODE_EMA, ma_period, amplitude, atr_period, atr_channel_deviation);
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
   ulong ord_tickets[];
   GetMyPositionsTickets(Magic, pos_tickets);
   GetMyOrdersTickets(Magic, ord_tickets);
   if(ArraySize(pos_tickets)>0 || ArraySize(ord_tickets)>0) return;
   CopyBuffer(heiken_ashi_handle, HAO_BUFFER, 0, 2, hao);
   CopyBuffer(heiken_ashi_handle, HAC_BUFFER, 1, 2, hac);
   CopyBuffer(heiken_ashi_handle, MA_BUFFER, 1, 2, ma);
   CopyBuffer(heiken_ashi_handle, UPDOWN_BUFFER, 1, 2, updown);
   CopyBuffer(heiken_ashi_handle, ATR_BUFFER, 1, 2, atr);
   ArrayReverse(hao, 0, WHOLE_ARRAY);
   ArrayReverse(hac, 0, WHOLE_ARRAY);
   ArrayReverse(ma, 0, WHOLE_ARRAY);
   ArrayReverse(updown, 0, WHOLE_ARRAY);
   ArrayReverse(atr, 0, WHOLE_ARRAY);
   
   if(updown[0]<updown[1] && hac[0]>ma[0]){  // buy
      entry_price = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
      //entry_price = hao[0];
      sl = NormalizeDouble(atr[0], _Digits);
      tp1 = NormalizeDouble(entry_price + (entry_price-sl)*rr_factor/2, _Digits);
      tp2 = NormalizeDouble(entry_price + (entry_price-sl)*rr_factor, _Digits);
      double lot = calculate_lot_size((entry_price-sl)/_Point, risk_per_trade);
      trade.Buy(lot/2, _Symbol, entry_price, sl, tp1);
      trade.Buy(lot/2, _Symbol, entry_price, sl, tp2);
   }else if(updown[0]>updown[1] && hac[0]<ma[0]){  // sell
      entry_price = SymbolInfoDouble(_Symbol,SYMBOL_BID);
      //entry_price = hao[0];
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
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskusd = risk * balance;
   //double contract = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE);
   double lot = riskusd/slpoints;
   lot = NormalizeDouble((MathFloor(lot*100/2)*2)/100,2);
   return lot;
}