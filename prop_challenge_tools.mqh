class PeriodData
{
public:
   datetime datetime_start;
   datetime datetime_end;
   double balance_start;
   double balance_end;
   double equity_start;
   double equity_end;
   double balance_min;
   double balance_max;
   double equity_min;
   double equity_max;
   void PeriodData(void);
   void update(void);
};

class PropChallengeCriteria
{
protected:
   PeriodData period_data[];
   double min_profit_usd;
   double max_drawdown_usd;
   ENUM_MONTH period_month;
  
public:
   void PropChallengeCriteria(void);
   void PropChallengeCriteria(double min_profit_usd, double max_drawdown_usd, ENUM_MONTH period_month);
   void update(void);
   double get_results(void);
};


void PeriodData::PeriodData(void){
   datetime_start = TimeCurrent();
   datetime_end = TimeCurrent();
   balance_start = AccountInfoDouble(ACCOUNT_BALANCE);
   balance_end = balance_start;
   balance_max = balance_start;
   balance_min = balance_start;
   equity_start = AccountInfoDouble(ACCOUNT_EQUITY);
   equity_end = equity_start;
   equity_max = equity_start;
   equity_min = equity_start;
}

void PeriodData::update(void){
   datetime_end = TimeCurrent();
   double bal = AccountInfoDouble(ACCOUNT_BALANCE);
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   balance_end = bal;
   equity_end = eq;
   if(bal>balance_max) balance_max = bal;
   if(bal<balance_min) balance_min = bal;
   if(eq>equity_max) equity_max = eq;
   if(eq<equity_min) equity_min = eq;
}


void PropChallengeCriteria::PropChallengeCriteria(double min_profit_usd_, double max_drawdown_usd_, ENUM_MONTH period_month_){
   min_profit_usd = min_profit_usd_;
   max_drawdown_usd = max_drawdown_usd_;
   period_month = period_month_;
}

void PropChallengeCriteria::update(void){
   int ndata = ArraySize(period_data);
   MqlDateTime current_time;
   TimeToStruct(TimeCurrent(), current_time);
   if(ndata>0){
      MqlDateTime last_period_time;
      TimeToStruct(period_data[ndata-1].datetime_end, last_period_time);
      if(last_period_time.year==current_time.year && last_period_time.mon==current_time.mon){
         period_data[ndata-1].update();
      }else if(current_time.mon==period_month || period_month==MONTH_ALL){
         ArrayResize(period_data, ndata+1);
         period_data[ndata] = PeriodData();
      } 
   }else if(current_time.mon==period_month || period_month==MONTH_ALL){
      ArrayResize(period_data, 1);
      period_data[0] = PeriodData();
   }
}

double PropChallengeCriteria::get_results(void){
   int ndata = ArraySize(period_data);
   double score=0;
   for(int i=0;i<ndata;i++){
      PeriodData data = period_data[i];
      if((data.balance_max-data.balance_start)>=min_profit_usd && (data.balance_start-data.equity_min)<=max_drawdown_usd) score++;
      else score--;
   }
   score /= ndata;
   return score;
}