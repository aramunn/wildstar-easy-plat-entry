require "Window"

local EasyPlatEntry = {}

-------------------------------------------------------------------------------
--constants
-------------------------------------------------------------------------------
--table of settings for sets of addons we want to hook into
--  addon: the name of the addon
--  hooks: info for sets of cash windows that already have the event we need
--    functions: info for individual event functions we're hooking into
--      post: function to call after setting cash window amount
--  adds: info for sets of cash windows we need to add events to
--    init: the function that loads the xml window(s) we want
--    base: name of variable containing base window
--    windows: info for individual windows we're targeting
--      post: function to call after setting cash window amount
--      paths: set of paths to the target cash windows
local sets = {
  {
    addon = "MarketplaceAuction",
    adds = {
      {
        init = "Initialize",
        base = "wndMain",
        windows = {
          {
            post = "ValidateSellOrder",
            paths = {
              {
                "SellContainer",
                "CreateBuyoutInputBox",
              },
              {
                "SellContainer",
                "CreateBidInputBox",
              },
            },
          },
          {
            -- post = "",
            -- paths = {
              -- {
                -- "BuyContainer",
                -- "BottomBidPrice",
              -- },
              -- {
                -- "AdvancedOptionsContainer",
                -- "FilterOptionsBuyoutCash",
              -- },
            -- },
          },
        },
      },
    },
  },
  -- {
    -- addon = "MarketplaceCommodity",
    -- methods = {
      -- method = "OnListInputPriceMouseDown",
    -- },
  -- },
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
--event called by hooked cash window
-------------------------------------------------------------------------------
function EasyPlatEntry:MouseButtonDownEventHook(cashWindow, addonName, postFunctionName)
  --destroy the previous window if it hasn't been already
  if self.wndMain and self.wndMain:IsValid() then self.wndMain:Destroy() end
  --load our pop-up window
  self.wndMain = Apollo.LoadForm(self.xmlDoc, "TextToMoneyForm", cashWindow, self)
  local editBox = self.wndMain:FindChild("EditBox")
  --get the amount currently in the cash window
  local amount = cashWindow:GetAmount()
  --add data to edit box for later
  editBox:SetData({
    addon = addonName,
    method = postFunctionName,
  })
  --set current value and focus on edit box
  editBox:SetText(convertAmountToString(amount))
  editBox:SetFocus()
end

-------------------------------------------------------------------------------
--when user hits enter in the edit box
-------------------------------------------------------------------------------
function EasyPlatEntry:OnEditBoxReturn(wndHandler, wndControl, strText)
  if not self.wndMain or not self.wndMain:IsValid() then return end
  local good, amount = convertStringToAmount(strText)
  if good then
    local cashWindow = self.wndMain:GetParent()
    cashWindow:SetAmount(amount)
    self.wndMain:Destroy()
    self.wndMain = nil
    local postData = wndControl:GetData()
    Print("Got "..postData.addon.." and "..postData.method)
    -- local addon = Apollo.GetAddon("MarketplaceAuction")
    -- addon:ValidateSellOrder()
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
--when user hits escape in the edit box
-------------------------------------------------------------------------------
function EasyPlatEntry:OnEditBoxEscape()
  if self.wndMain and self.wndMain:IsValid() then self.wndMain:Destroy() end
end

-------------------------------------------------------------------------------
--when user clicks off of the pop-up window (also called after escape)
-------------------------------------------------------------------------------
function EasyPlatEntry:OnWindowLostFocus()
end

-------------------------------------------------------------------------------
--when user clicks off of the pop-up window
-------------------------------------------------------------------------------
function EasyPlatEntry:OnWindowClosed()
end

-------------------------------------------------------------------------------
--timer functions
-------------------------------------------------------------------------------
function EasyPlatEntry:OnPixieTimer()
  self.wndMain:DestroyPixie(errorPixie)
end

-------------------------------------------------------------------------------
--used to hook our event into cash window
-------------------------------------------------------------------------------
local function hookMouseButtonDownEvent(addon, windows)
  --extract old method we're replacing
  local method = addon[windows.init]
  --replace old method with itself plus an event handler
  addon[windows.init] = function (...)
    method(...)
    --iterate through the sets of paths
    for idx, path in ipairs(windows.paths) do
      local cashWindow = addon["wndMain"]
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
--hook settings processing
-------------------------------------------------------------------------------
function EasyPlatEntry:ProcessAdd(addon, data)
  if data.windows then
    --hook into the addon
    hookMouseButtonDownEvent(addon, data.windows)
    --add event handler to addon
    addon[eventFunctionName] = function(wndHandler, wndControl) self:MouseButtonDownEvent(wndControl, addon, "ValidateSellOrder") end
  end
  -- if hook.methods then
    -- -- extract old method we're replacing
    -- local method = addon[hook.methods.method]
    -- -- replace old method with itself plus an event handler
    -- addon[hook.methods.method] = function (...)
      -- method(...)
      -- self:MouseButtonDownEvent(...)
    -- end
  -- end
end

function EasyPlatEntry:ProcessSets()
  --iterate through settings
  for idx, set in ipairs(sets) do
    --get addon and make sure it is active
    local addon = Apollo.GetAddon(set.addon)
    if addon ~= nil then
      for idx, add in ipairs(set.adds) do
        self:ProcessAdd(addon, add)
      end
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
  self:ProcessSets()
end

-------------------------------------------------------------------------------
--set up addon
-------------------------------------------------------------------------------
local errorPixie
local EasyPlatEntryInst = EasyPlatEntry:new()
EasyPlatEntryInst:Init()
