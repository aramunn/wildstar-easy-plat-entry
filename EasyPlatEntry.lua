require "Window"

local EasyPlatEntry = {}

-------------------------------------------------------------------------------
--constants
-------------------------------------------------------------------------------
--table for hook settings
--  addon: the name of the addon we're hooking into
--  windows: set of windows we need to add events to
--    method: the function that loads the xml window(s) we want to hook
--    paths: window names leading to the window we want
local hooks = {
  {
    addon = "MarketplaceAuction",
    windows = {
      method = "Initialize",
      paths = {
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
  },
}

local eventFunctionName = "EasyPlatEntryHook"

-------------------------------------------------------------------------------
--using a cash amount, build a string in proper format
-------------------------------------------------------------------------------
local function convertAmountToString(amt)
  local curAmtStr = ""
  local denominations = { "c", "s", "g", "p" }
  for idx, denomination in ipairs(denominations) do
    --extract denomination value from amount
    local value = amt
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
    amt = (amt - value) / 100
  end
  return curAmtStr
end

-------------------------------------------------------------------------------
--parse a (hopefully) formatted string
-------------------------------------------------------------------------------
local function convertStringToAmount(str)
  local strToParse = string.lower(str)
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
  local matches = strToCompare == string.lower(string.gsub(str, '%s', ""))
  return matches, total
end

-------------------------------------------------------------------------------
--used to hook our event into cash window
-------------------------------------------------------------------------------
local function hookMouseButtonDownEvent(addon, windows)
  --extract old method we're replacing
  local method = addon[windows.method]
  --replace old method with itself plus an event handler
  addon[windows.method] = function (...)
    method(...)
    --iterate through the sets of paths
    for idx, path in ipairs(windows.paths) do
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
--event called by hooked cash window
-------------------------------------------------------------------------------
function EasyPlatEntry:MouseButtonDownEvent(wndHandler, wndControl)
  --destroy the previous window if it hasn't been already
  if self.wndMain and self.wndMain:IsValid() then self.wndMain:Destroy() end
  --load our pop-up window
  self.wndMain = Apollo.LoadForm(self.xmlDoc, "TextToMoneyForm", wndControl, self)
  local editBox = self.wndMain:FindChild("EditBox")
  --get the amount currently in the cash window
  local amount = wndControl:GetAmount()
  --set current value and focus on edit box
  editBox:SetText(convertAmountToString(amount))
  editBox:SetFocus()
end

-------------------------------------------------------------------------------
--when user hits enter in the edit box
-------------------------------------------------------------------------------
function EasyPlatEntry:OnEditBoxReturn(wndHandler, wndControl, strText)
  --parse string
  local good, amount = convertStringToAmount(strText)
  if good then
    local cashWindow = self.wndMain:GetParent()
    cashWindow:SetAmount(amount)
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
--hook settings processing
-------------------------------------------------------------------------------
function EasyPlatEntry:ProcessHook(addon, hook)
  if hook.windows then
    --hook into the addon
    hookMouseButtonDownEvent(addon, hook.windows)
    --add event handler to addon
    addon[eventFunctionName] = function(wndHandler, wndControl) self:MouseButtonDownEvent(wndHandler, wndControl) end
  end
end

function EasyPlatEntry:ProcessHooks()
  --iterate through hooks
  for idx, hook in ipairs(hooks) do
    --get addon and make sure it is active
    local addon = Apollo.GetAddon(hook.addon)
    if addon ~= nil then
      self:ProcessHook(addon, hook)
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

function EasyPlatEntry:OnDocumentReady()
  --make sure xml is loaded
  if self.xmlDoc == nil then return end
  if not self.xmlDoc:IsLoaded() then return end
  --hook into addons
  self:ProcessHooks()
end

-------------------------------------------------------------------------------
--set up addon
-------------------------------------------------------------------------------
local errorPixie
local EasyPlatEntryInst = EasyPlatEntry:new()
EasyPlatEntryInst:Init()
