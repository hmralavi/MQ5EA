/*
------------------------------------------------------------
EA made by hamid alavi.


Strategy:
   1- open a buy/sell position with specified lots, sl and tp.
   2- if it hits tp, go to step 1. otherwise go to step 3.
   3- if it hits sl, double the lots and enter into an opposite trade.  then go to step 2.

TODO:
   
-------------------------------------------------------------
*/


#include <Trade/Trade.mqh>

input double Lots = 0.01;
input double LotFactor = 2;
input double LotLimit = 0.2;
input int TpPoints = 30;
input int SlPoints = 30;
input int Magic = 111;

CTrade trade;
bool buy = true;
double adaptiveLots = Lots;

int OnInit()
  {
   trade.SetExpertMagicNumber(Magic);
   trade.SetDeviationInPoints(20);
   return(INIT_SUCCEEDED);
  }


void OnDeinit(const int reason)
  {
   
  }


void OnTick()
  {
   if(PositionsTotal()>0) return;
   if(buy){
      double ask = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
      double bid = SymbolInfoDouble(_Symbol,SYMBOL_BID);
      double tp = ask + TpPoints * _Point;
      double sl = bid - SlPoints * _Point;
      
      ask = NormalizeDouble(ask,_Digits);
      tp = NormalizeDouble(tp,_Digits);
      sl = NormalizeDouble(sl,_Digits);
      
      trade.Buy(adaptiveLots,_Symbol,ask,sl,tp);
    }else{
      double ask = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
      double bid = SymbolInfoDouble(_Symbol,SYMBOL_BID);
      double tp = bid - TpPoints * _Point;
      double sl = ask + SlPoints * _Point;
      
      bid = NormalizeDouble(bid,_Digits);
      tp = NormalizeDouble(tp,_Digits);
      sl = NormalizeDouble(sl,_Digits);
      
      trade.Sell(adaptiveLots,_Symbol,bid,sl,tp);
    }
   
  }


void OnTradeTransaction(const MqlTradeTransaction& trans,
                        const MqlTradeRequest& request,
                        const MqlTradeResult& result)
  {
   
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD){
      CDealInfo deal;
      deal.Ticket(trans.deal);
      HistorySelect(TimeCurrent()-PeriodSeconds(PERIOD_D1), TimeCurrent()+10);
      if(deal.Magic()==Magic && deal.Symbol()==_Symbol){
         if(deal.Entry()==DEAL_ENTRY_OUT){
            Print(__FUNCTION__, "> closed pos #", trans.position);
            if(deal.Profit()>=0){
               buy = !buy;
               adaptiveLots = Lots;
            }else{
               adaptiveLots = MathMin(NormalizeDouble(deal.Volume() * LotFactor, 2), LotLimit);
               if(deal.DealType()==DEAL_TYPE_BUY){
                  buy = true;      
               }else if(deal.DealType()==DEAL_TYPE_SELL){
                  buy = false;
               }
            
            }
         }
      }
   }
   
   
  }
