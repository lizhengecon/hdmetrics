### Double ML: UI Bonus Example
### Jeremy LHour
### 08/01/2018
### Edited: 28/02/2018

### This is an empirical example from Chernozhukov et al. (2017) procedure to
### Estimate ATT assuming heteregeneous effects.
### Data is from Bilias (2000) on the effect of Unemployment Insurance Bonus on
### Unemployment duration.

### See Chernozhukov's paper for more complete results.


### Set working directory
setwd("//ulysse/users/JL.HOUR/1A_These/B. ENSAE Classes/Cours3A/hdmetrics")

rm(list=ls())
set.seed(101)


### 0. Settings

### Packages
library("hdm")
library("randomForest")

### Load user-defined functions
source("functions/ATE.R")

### Pennsylvania Bonus Data
Penn = as.data.frame(read.table("data/penn_jae.dat", header=T ))

index = (Penn$tg==0) | (Penn$tg==4) # Only keep treatment=4 and controls
data = Penn[index,]
data$tg[data$tg==4] = 1
data[,"dep1"] = data$dep==1
data[,"dep2"] = data$dep==2
data$inuidur1 = log(data$inuidur1)


Y = data[,"inuidur1"] # Outcome
D = data[,"tg"] # Treatment
X = as.matrix(data[,c("female","black","othrace","dep1","dep2",
                      "q2","q3","q4","q5","q6","agelt35","agegt54","durable","lusd","husd")]) # Covariates

K = 5
n = length(Y)

###############################################
###############################################
### 1. Simple DML w Lasso and Random Forest ###
###############################################
###############################################

split = runif(n)
cvgroup = as.numeric(cut(split,quantile(split,probs = seq(0, 1, 1/K)),include.lowest = T))

thetaL = vector(length=K); gammaL = vector(length=n)
thetaRF = vector(length=K); gammaRF = vector(length=n)

for(k in 1:K){
  Ik = cvgroup==k # Split the sample
  NIk = cvgroup!=k
  
  # A. Propensity Score
  treatfit = rlassologit(D[NIk] ~ X[NIk,]) # Logit Lasso
  mhatL = predict(treatfit,newdata=X[Ik,])
  
  optRF = tuneRF(X[NIk,],as.factor(D[NIk]),stepFactor=1.5, improve=0.05, nodesize=5, doBest=T, plot=F, trace=F)
  min = optRF$mtry
  treatForest = randomForest(X[NIk,],as.factor(D[NIk]), mtry=min)
  mhatRF = predict(treatForest, X[Ik,], type="prob")[,2]
  
  # B. E(Y_0 \vert X)
  outcomefit0 = rlasso(Y[D[NIk]==0] ~ X[D[NIk]==0,]) # Lasso
  g0hatL = predict(outcomefit0,newdata = X[Ik,])
  
  optRF = tuneRF(X[D[NIk]==0,],Y[D[NIk]==0],stepFactor=1.5, improve=0.05, nodesize=5, doBest=T, plot=F, trace=F)
  min = optRF$mtry
  outcomeForest0 = randomForest(X[D[NIk]==0,],Y[D[NIk]==0], mtry=min)
  g0hatRF = predict(outcomeForest0, X[D[Ik],], type="response")
  
  # C. ATT
  thetaL[k] = ATT(Y[Ik],D[Ik],g0hatL,mhatL)
  gammaL[Ik] = SE.ATT(Y[Ik],D[Ik],g0hatL,mhatL)$gamma
  
  thetaRF[k] = ATT(Y[Ik],D[Ik],g0hatRF,mhatRF)
  gammaRF[Ik] = SE.ATT(Y[Ik],D[Ik],g0hatRF,mhatRF)$gamma
}

### Results

## A. Lasso
SE.thetaL = sd(gammaL)/sqrt(n)

print("ATT, Point estimate")
print(mean(thetaL))
print("Standard Error")
print(SE.thetaL)
print(".95 Confidence Interval")
print(paste("[",mean(thetaL)+qnorm(.025)*SE.thetaL,";",mean(thetaL)+qnorm(.975)*SE.thetaL,"]"))

### B. Random Forest
SE.thetaRF = sd(gammaRF)/sqrt(n)

print("ATT, Point estimate")
print(mean(thetaRF))
print("Standard Error")
print(SE.thetaRF)
print(".95 Confidence Interval")
print(paste("[",mean(thetaRF)+qnorm(.025)*SE.thetaRF,";",mean(thetaRF)+qnorm(.975)*SE.thetaRF,"]"))


########################################################
########################################################
### 2. Median to mitigate impact of sample-splitting ###
########################################################
########################################################

# cf. DML paper, definition 3.3, p. 30
# Here the partition of the sample is recomputed S times
S = 20

thetaL = matrix(nrow=K,ncol=S); gammaL = matrix(nrow=n,ncol=S)
thetaRF = matrix(nrow=K,ncol=S); gammaRF = matrix(nrow=n,ncol=S)

for(s in 1:S){
  split = runif(n)
  cvgroup = as.numeric(cut(split,quantile(split,probs = seq(0, 1, 1/K)),include.lowest = T))
  
  for(k in 1:K){
    Ik = cvgroup==k # Split the sample
    NIk = cvgroup!=k
    
    # A. Propensity Score
    treatfit = rlassologit(D[NIk] ~ X[NIk,]) # Logit Lasso
    mhatL = predict(treatfit,newdata=X[Ik,])
    
    optRF = tuneRF(X[NIk,],as.factor(D[NIk]),stepFactor=1.5, improve=0.05, nodesize=5, doBest=T, plot=F, trace=F)
    min = optRF$mtry
    treatForest = randomForest(X[NIk,],as.factor(D[NIk]), mtry=min)
    mhatRF = predict(treatForest, X[Ik,], type="prob")[,2]
    
    # B. E(Y_0 \vert X)
    outcomefit0 = rlasso(Y[D[NIk]==0] ~ X[D[NIk]==0,]) # Lasso
    g0hatL = predict(outcomefit0,newdata = X[Ik,])
    
    optRF = tuneRF(X[D[NIk]==0,],Y[D[NIk]==0],stepFactor=1.5, improve=0.05, nodesize=5, doBest=T, plot=F, trace=F)
    min = optRF$mtry
    outcomeForest0 = randomForest(X[D[NIk]==0,],Y[D[NIk]==0], mtry=min)
    g0hatRF = predict(outcomeForest0, X[D[Ik],], type="response")
    
    # C. ATT
    thetaL[k,s] = ATT(Y[Ik],D[Ik],g0hatL,mhatL)
    gammaL[Ik,s] = SE.ATT(Y[Ik],D[Ik],g0hatL,mhatL)$gamma
    
    thetaRF[k,s] = ATT(Y[Ik],D[Ik],g0hatRF,mhatRF)
    gammaRF[Ik,s] = SE.ATT(Y[Ik],D[Ik],g0hatRF,mhatRF)$gamma
  }
}

### Results based on the median

## A. Lasso
thetaL.DML = apply(thetaL,2,mean)
thetaL.med = median(thetaL.DML)
SE.thetaL = apply(gammaL,2,sd)/sqrt(n)

print("ATT, Point estimate")
print(thetaL.med)
print("Standard Error")
print(sqrt(median(SE.thetaL^2 +  (thetaL.DML-thetaL.med)^2)))

### B. Random Forest
thetaRF.DML = apply(thetaRF,2,mean)
thetaRF.med = median(thetaRF.DML)
SE.thetaRF = apply(gammaRF,2,sd)/sqrt(n)

print("ATT, Point estimate")
print(thetaRF.med)
print("Standard Error")
print(sqrt(median(SE.thetaRF^2 +  (thetaRF.DML-thetaRF.med)^2)))