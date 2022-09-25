/*
TODO:
   position volume risk management for other forex pairs.
*/

#include <../Experts/mq5ea/mytools.mqh>


input string __str1 = "";  // ---------MAIN SETTINGS---------
input ENUM_TIMEFRAMES main_time_frame = PERIOD_M1;
input bool use_heiken_ashi_candles = true;
input int ma_period = 200;
input int amplitude = 3;
input int atr_period = 14;
input double atr_channel_deviation = 2.0;
input double risk_per_trade = 2;  // risk %
input double rr_factor = 2;
input int Magic = 130;  // EA's magic number
input string __str2 = "";  // ---------TRADING SESSIONS SETTINGS---------
input bool trade_only_in_session_time = false;
input string session_start_time = "09:00";      // session start (server time)
input string session_end_time = "19:00";        // session end (server time)    
input string __str3 = "";  // ---------TREND TRADING SETTINGS---------
input bool use_higher_timeframe_trend1 = false;
input bool use_higher_timeframe_trend2 = false;
input ENUM_TIMEFRAMES higher_timeframe1 = PERIOD_H1;
input ENUM_TIMEFRAMES higher_timeframe2 = PERIOD_H4;
input int timeframe1_amplitude = 1;
input int timeframe2_amplitude = 1;

CTrade trade;
int heiken_ashi_handle, heiken_ashi_handle1, heiken_ashi_handle2;
double hac[], ma[], updown[], atr[];
double updown1[], updown2[];
double sl, tp1, tp2, entry_price;

#define HAC_BUFFER 3
#define MA_BUFFER 5
#define UPDOWN_BUFFER 8
#define ATR_BUFFER 9

int OnInit(){  
   trade.SetExpertMagicNumber(Magic);
   heiken_ashi_handle = iCustom(_Symbol, main_time_frame, "..\\Experts\\mq5ea\\indicators\\heiken_ashi_ema_halftrend.ex5", use_heiken_ashi_candles, MODE_EMA, ma_period, amplitude, atr_period, atr_channel_deviation);
   heiken_ashi_handle1 = iCustom(_Symbol, higher_timeframe1, "..\\Experts\\mq5ea\\indicators\\heiken_ashi_ema_halftrend.ex5", use_heiken_ashi_candles, MODE_EMA, ma_period, timeframe1_amplitude, atr_period, atr_channel_deviation);
   heiken_ashi_handle2 = iCustom(_Symbol, higher_timeframe2, "..\\Experts\\mq5ea\\indicators\\heiken_ashi_ema_halftrend.ex5", use_heiken_ashi_candles, MODE_EMA, ma_period, timeframe2_amplitude, atr_period, atr_channel_deviation);
   ObjectsDeleteAll(0);
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason){
   IndicatorRelease(heiken_ashi_handle);
   IndicatorRelease(heiken_ashi_handle1);
   IndicatorRelease(heiken_ashi_handle2);
}

void OnTick(){  
   if(!IsNewCandle(main_time_frame)) return;
   if(!is_session_time_allowed(session_start_time, session_end_time) && trade_only_in_session_time) return;   
   ulong pos_tickets[];
   ulong ord_tickets[];
   GetMyPositionsTickets(Magic, pos_tickets);
   GetMyOrdersTickets(Magic, ord_tickets);
   if(ArraySize(pos_tickets)>0 || ArraySize(ord_tickets)>0) return;
   CopyBuffer(heiken_ashi_handle, HAC_BUFFER, 1, 2, hac);
   CopyBuffer(heiken_ashi_handle, MA_BUFFER, 1, 3, ma);
   CopyBuffer(heiken_ashi_handle, UPDOWN_BUFFER, 1, 3, updown);
   CopyBuffer(heiken_ashi_handle, ATR_BUFFER, 1, 2, atr);
   ArrayReverse(hac, 0, WHOLE_ARRAY);
   ArrayReverse(ma, 0, WHOLE_ARRAY);
   ArrayReverse(updown, 0, WHOLE_ARRAY);
   ArrayReverse(atr, 0, WHOLE_ARRAY);
   
   CopyBuffer(heiken_ashi_handle1, UPDOWN_BUFFER, 0, 2, updown1);
   CopyBuffer(heiken_ashi_handle2, UPDOWN_BUFFER, 0, 2, updown2);
   ArrayReverse(updown1, 0, WHOLE_ARRAY);
   ArrayReverse(updown2, 0, WHOLE_ARRAY);
   
   if((updown[0]<updown[1] || updown[0]<updown[2])  && 
      (hac[0]>ma[0] || hac[0]>ma[1] || hac[0]>ma[2])){  // buy
      if(use_higher_timeframe_trend1){
         if(updown1[0]!=0.0 || updown1[1]!=0.0) return;
      }
      if(use_higher_timeframe_trend2){
         if(updown2[0]!=0.0 || updown2[1]!=0.0) return;
      }
      entry_price = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
      sl = NormalizeDouble(atr[0], _Digits);
      tp1 = NormalizeDouble(entry_price + (entry_price-sl)*rr_factor/2, _Digits);
      tp2 = NormalizeDouble(entry_price + (entry_price-sl)*rr_factor, _Digits);
      double lot = calculate_lot_size((entry_price-sl)/_Point, risk_per_trade);
      trade.Buy(lot/2, _Symbol, entry_price, sl, tp1);
      trade.Buy(lot/2, _Symbol, entry_price, sl, tp2);
   }else if((updown[0]>updown[1] || updown[0]>updown[2])  && 
      (hac[0]<ma[0] || hac[0]<ma[1] || hac[0]<ma[2])){  // sell
      if(use_higher_timeframe_trend1){
         if(updown1[0]!=1.0 || updown1[1]!=1.0) return;
      }
      if(use_higher_timeframe_trend2){
         if(updown2[0]!=1.0 || updown2[1]!=1.0) return;
      }      
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
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskusd = risk * balance / 100;
   //double contract = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE);
   double lot = riskusd/slpoints;
   lot = NormalizeDouble((MathFloor(lot*100/2)*2)/100,2);
   return lot;
}