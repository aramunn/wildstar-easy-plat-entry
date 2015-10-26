require "Window"

local EasyPlatEntry = {}

-------------------------------------------------------------------------------
--constants
-------------------------------------------------------------------------------
--table for hook settings
--  addonToHook: the name of the addon we're hooking into
--  methodToHook: the function that loads the xml window we want to hook
--  pathToWindowsToHook:
local Hooks = {
  {
    addonToHook = "MarketplaceAuction",
    methodToHook = "Initialize",
    pathToWindowsToHook = {
      {
        "SellContainer",
        "CreateBuyoutInputBox",
      },
      {
        "SellContainer",
        "CreateBidInputBox",
      },
      -- {
        -- "BuyContainer",
        -- "BottomBidPrice",
      -- },
      -- {
        -- "AdvancedOptionsContainer",
        -- "FilterOptionsBuyoutCash",
      -- },
    },
  },
}

local eventFunctionName = "EasyPlatEntryHook"

-------------------------------------------------------------------------------
--used to hook our event into cash window
-------------------------------------------------------------------------------
local function hookMouseButtonDownEvent(addon, hook)
  --extract old method we're replacing
  local method = addon[hook.methodToHook]
  --replace old method with itself plus an event handler
  addon[hook.methodToHook] = function (...)
    method(...)
    --iterate through the sets of paths
    for idx, path in ipairs(hook.pathToWindowsToHook) do
      local cashWindow = addon.wndMain --TODO probably need to parametrize this
      --iterate through windows in path
      for idx, child in ipairs(path) do
        cashWindow = cashWindow:FindChild(child)
      end
      --add our event handler for when user clicks in cash window
      cashWindow:AddEventHandler("MouseButtonDown", eventFunctionName)
    end
  end
end

-------------------------------------------------------------------------------
--required addon functions
-------------------------------------------------------------------------------
function EasyPlatEntry:new(o)
  o = o or {}
  setmetatable(o, self)
  self.__index = self
  return o
end

function EasyPlatEntry:Init()
  Apollo.RegisterAddon(self)
end

function EasyPlatEntry:OnLoad()
  self.xmlDoc = XmlDoc.CreateFromFile("EasyPlatEntry.xml")
  self.xmlDoc:RegisterCallback("OnDocumentReady", self)
end

function EasyPlatEntry:OnDocumentReady() --TODO maybe put this on a timer. would any addons not be loaded at this point?
  --make sure xml is loaded
  if self.xmlDoc == nil then return end
  if not self.xmlDoc:IsLoaded() then return end
  --iterate through hooks
  for idx, hook in ipairs(Hooks) do
    --get addon and make sure it is active
    local addon = Apollo.GetAddon(hook.addonToHook)
    if addon ~= nil then
      --hook into the addon
      hookMouseButtonDownEvent(addon, hook)
      --add event handler to addon
      addon[eventFunctionName] = function(wndHandler, wndControl) self:MouseButtonDownEvent(wndHandler, wndControl) end
    end
  end
end

-------------------------------------------------------------------------------
--event called by hooked cash window
-------------------------------------------------------------------------------
function EasyPlatEntry:MouseButtonDownEvent(wndHandler, wndControl)
  --destroy the previous window if it hasn't been already
  if self.wndMain and self.wndMain:IsValid() then self.wndMain:Destroy() end
  --get the amount currently in the cash window
  local amount = wndControl:GetAmount()
  --build string in format we're expecting using current value
  local curAmtStr = ""
  local denominations = { "c", "s", "g", "p" }
  for idx, denomination in ipairs(denominations) do
    --extract denomination value from amount
    local value = amount
    if idx < #denominations then value = value % 100 end
    --add value to string if not zero
    if value > 0 then
      --add space if more than one value in this string
      if curAmtStr ~= "" then
        curAmtStr = " "..curAmtStr
      end
      --add value and denomination character to front of string
      curAmtStr = value..denomination..curAmtStr
    end
    --adjust amount
    amount = (amount - value) / 100
  end
  --load our pop-up window then set current value and focus on edit box
  self.wndMain = Apollo.LoadForm(self.xmlDoc, "TextToMoneyForm", wndControl, self)
  local editBox = self.wndMain:FindChild("EditBox")
  editBox:SetText(curAmtStr)
  editBox:SetFocus()
end

-------------------------------------------------------------------------------
--when user hits enter in the edit box
-------------------------------------------------------------------------------
function EasyPlatEntry:OnEditBoxReturn(wndHandler, wndControl, strText)
  --parse string
  local strToParse = string.lower(strText)
  local total = 0
  local strToCompare = ""
  local denominations = { "p", "g", "s", "c" }
  for idx, denomination in ipairs(denominations) do
    --get a number followed by a denomination character
    local value, remaining = string.match(strToParse, "^%s*(%d+)%s*"..denomination.."(.*)$")
    if value ~= nil then
      --add appropriate amount to total
      total = total + math.floor(tonumber(value) * math.pow(100, #denominations - idx))
      strToParse = remaining
      strToCompare = strToCompare..value..denomination
    end
  end
  --check if the string we made matches the user's input
  if strToCompare == string.lower(string.gsub(strText, '%s', "")) then
    local cashWindow = self.wndMain:GetParent()
    cashWindow:SetAmount(total)
    self.wndMain:Destroy()
    self.wndMain = nil
    local addon = Apollo.GetAddon("MarketplaceAuction")
    addon:ValidateSellOrder()
    -- local wndParent = wndHandler:GetData()
    -- wndParent:FindChild("BottomBidResetBtn"):Show(true)
    -- addon:HelperValidateBidEditBoxInput()
  else
    errorPixie = self.wndMain:AddPixie({
      strSprite = "CRB_NameplateSprites:sprNp_VulnerableBarFlash",
      loc = {
        fPoints = {0,0,1,1},
        nOffsets = {5,0,-5,2}
      },
      cr = "AddonError"
    })
    self.timer = ApolloTimer.Create(0.5, false, "OnPixieTimer", self)
  end
end

-------------------------------------------------------------------------------
--timer functions
-------------------------------------------------------------------------------
function EasyPlatEntry:OnPixieTimer()
  self.wndMain:DestroyPixie(errorPixie)
end

-------------------------------------------------------------------------------
--set up addon
-------------------------------------------------------------------------------
local errorPixie
local EasyPlatEntryInst = EasyPlatEntry:new()
EasyPlatEntryInst:Init()
