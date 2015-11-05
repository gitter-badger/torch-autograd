-- A comparison between autograd and nngraph
-- using an L2-regularized autoencoder with tied weights.

-- Libs
local grad = require 'autograd'
local lossFuns = require 'autograd.loss'
local util = require 'autograd.util'
local optim = require 'optim'

-- Load in MNIST
local trainData, testData, classes = require('./get-mnist.lua')()
local inputSize = trainData.x[1]:nElement()

-- What model to train:
local predict,f,params

-- Define our neural net
function predict(params, input)
   -- Encoder
   local h1 = util.sigmoid(input * params.W[1] + torch.expand(params.B[1], input:size(1), params.B[1]:size(2)))
   local h2 = util.sigmoid(h1 * params.W[2] + torch.expand(params.B[2], input:size(1), params.B[2]:size(2)))
   local h3 = util.sigmoid(h2 * params.W[3] + torch.expand(params.B[3], input:size(1), params.B[3]:size(2)))

   -- Decoder
   local h4 = util.sigmoid(h3 * torch.t(params.W[3]) + torch.expand(params.B[4], input:size(1), params.B[4]:size(2)))
   local h5 = util.sigmoid(h4 * torch.t(params.W[2]) + torch.expand(params.B[5], input:size(1), params.B[5]:size(2)))
   local out = util.sigmoid(h5 * torch.t(params.W[1]) + torch.expand(params.B[6], input:size(1), params.B[6]:size(2)))

   return out
end

-- Define our training loss
function f(params, input, l2Lambda)
   -- Reconstruction loss
   local prediction = predict(params, input)
   local loss = lossFuns.logBCELoss(prediction, input)

   -- L2 penalty on the weights
   for i=1,#params.W do
      loss = loss + l2Lambda * torch.sum(torch.pow(params.W[i],2))
   end

   return loss, prediction
end

-- Get the gradients closure magically:
local df = grad(f)

sizes = {}
sizes['input'] = inputSize
sizes['h1'] = 50
sizes['h2'] = 25
sizes['h3'] = 10

-- L2 penalty strength
l2Lambda = 1e-3

-- Define our parameters
-- [-1/sqrt(#output), 1/sqrt(#output)]
torch.manualSeed(0)
local W1 = torch.FloatTensor(sizes['input'],sizes['h1']):uniform(-1/math.sqrt(sizes['h1']),1/math.sqrt(sizes['h1']))
local W2 = torch.FloatTensor(sizes['h1'],sizes['h2']):uniform(-1/math.sqrt(sizes['h2']),1/math.sqrt(sizes['h2']))
local W3 = torch.FloatTensor(sizes['h2'],sizes['h3']):uniform(-1/math.sqrt(sizes['h3']),1/math.sqrt(sizes['h3']))
local B1 = torch.FloatTensor(1, sizes['h1']):fill(0)
local B2 = torch.FloatTensor(1, sizes['h2']):fill(0)
local B3 = torch.FloatTensor(1, sizes['h3']):fill(0)
local B4 = torch.FloatTensor(1, sizes['h2']):fill(0)
local B5 = torch.FloatTensor(1, sizes['h1']):fill(0)
local B6 = torch.FloatTensor(1, sizes['input']):fill(0)

-- Trainable parameters:
params = {
   W = {W1, W2, W3},
   B = {B1, B2, B3, B4, B5, B6},
}

loss, preds = f(params, trainData.x[1]:view(1, inputSize), l2Lambda)
grads, loss, preds = df(params, trainData.x[1]:view(1, inputSize), l2Lambda)

-- Train a neural network
for epoch = 1,100 do
   print('Training Epoch #'..epoch)
   for i = 1,trainData.size do
      -- Next sample:
      local x = trainData.x[i]:view(1,inputSize)

      -- Grads:
      local grads, loss, prediction = df(params,x,l2Lambda)

      -- Update weights and biases
      for i=1,#params.W do
         params.W[i] = params.W[i] - grads.W[i] * 0.01
      end

      for i=1,#params.B do
         params.B[i] = params.B[i] - grads.B[i] * 0.01
      end
   end

   -- Log performance:
   print('Cross-entropy loss: '..f(params, trainData.x:view(60000, -1), l2Lambda))
end