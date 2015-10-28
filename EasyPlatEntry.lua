require "Window"

local EasyPlatEntry = {}

-------------------------------------------------------------------------------
--constants
-------------------------------------------------------------------------------
--table of sets of addons we want to hook into
--  addon: name of the addon
--  method: method we're adding onto
--  [base]: name of the variable containing the base window
--  [path]: path to the target cash window
--  post: function to call after setting a new amount
local sets = {
  {
    addon = "MarketplaceAuction",
    method = "Initialize",
    base = "wndMain",
    path = "CreateBuyoutInputBox",
    post = "OnCreateBuyoutInputBoxChanged",
  },
  {
    addon = "MarketplaceAuction",
    method = "Initialize",
    base = "wndMain",
    path = "CreateBidInputBox",
    post = "OnCreateBidInputBoxChanged",
  },
  -- {
    -- addon = "MarketplaceAuction",
    -- method = "Initialize",
    -- base = "wndMain",
    -- path = "BuyContainer:BottomBidPrice",
    -- post = "",
  -- },
  -- {
    -- addon = "MarketplaceAuction",
    -- method = "Initialize",
    -- base = "wndMain",
    -- path = "AdvancedOptionsContainer:FilterOptionsBuyoutCash",
    -- post = "",
  -- },
  -- {
    -- addon = "MarketplaceCommodity",
    -- method = "OnListInputPriceMouseDown",
    -- post = "",
  -- },
}

--what to call the methods we add to other addons
local eventFunctionPrefix = "EasyPlatEntryEvent"

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
      --update our strings
      strToParse = remaining
      strToCompare = strToCompare..value..denomination
    end
  end
  --check if the string we made matches the user's input
  local matches = strToCompare == string.lower(string.gsub(str, '%s', ""))
  return matches, total
end

-------------------------------------------------------------------------------
--timer functions
-------------------------------------------------------------------------------
function EasyPlatEntry:OnPixieTimer()
  self.wndMain:DestroyPixie(errorPixie)
end

-------------------------------------------------------------------------------
--when user hits escape in the edit box
-------------------------------------------------------------------------------
function EasyPlatEntry:OnEditBoxEscape()
  if self.wndMain and self.wndMain:IsValid() then self.wndMain:Destroy() end
end

-------------------------------------------------------------------------------
--when user clicks off of the pop-up window
-------------------------------------------------------------------------------
function EasyPlatEntry:OnWindowClosed()
end

-------------------------------------------------------------------------------
--when user hits enter in the edit box
-------------------------------------------------------------------------------
function EasyPlatEntry:OnEditBoxReturn(wndHandler, wndControl, strText)
  --ensure our window is up
  if not self.wndMain or not self.wndMain:IsValid() then return end
  --attempt to get value from string
  local good, amount = convertStringToAmount(strText)
  if good then
    --set the new amount
    local cashWindow = self.wndMain:GetParent()
    cashWindow:SetAmount(amount)
    --call post method if needed
    local postData = wndControl:GetData()
    if postData and postData.post ~= "" then
      local addon = Apollo.GetAddon(postData.addon)
      addon[postData.post](addon)
    end
    --close our pop-up
    self.wndMain:Destroy()
    self.wndMain = nil
  else
    --create an error flash
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
--event called by hooked cash window
-------------------------------------------------------------------------------
function EasyPlatEntry:MouseButtonDownEvent(cashWindow, addonName, postFunctionName)
  --destroy the previous window if it hasn't been already
  if self.wndMain and self.wndMain:IsValid() then self.wndMain:Destroy() end
  --load our pop-up window
  self.wndMain = Apollo.LoadForm(self.xmlDoc, "EasyPlatEntryForm", cashWindow, self)
  local editBox = self.wndMain:FindChild("EditBox")
  --add data to edit box for later
  editBox:SetData({
    addon = addonName,
    post = postFunctionName,
  })
  --set current value and focus on edit box
  local amount = cashWindow:GetAmount()
  editBox:SetText(convertAmountToString(amount))
  editBox:SetFocus()
end

-------------------------------------------------------------------------------
--set processing
-------------------------------------------------------------------------------
function EasyPlatEntry:ProcessSet(set, addon)
  --add extra code to a function in addon
  local method = addon[set.method]
  addon[set.method] = function (...)
    method(...)
    if set.path then
      --we need to add an event handler to a window and the addon
      local eventFunctionName = eventFunctionPrefix
      if set.post then eventFunctionName = eventFunctionName.."With"..set.post end
      local cashWindow = addon[set.base]:FindChild(set.path)
      cashWindow:AddEventHandler("MouseButtonDown", eventFunctionName)
      addon[eventFunctionName] = function(wndHandler, wndControl) self:MouseButtonDownEvent(wndControl, set.addon, set.post) end
    else
      --we only need to add to the existing handler
      local wndControl = arg[2]
      self:MouseButtonDownEvent(wndControl, set.addon, set.post)
    end
  end
end

function EasyPlatEntry:ProcessSets()
  --iterate through sets
  for idx, set in ipairs(sets) do
    --ensure addon is running
    local addon = Apollo.GetAddon(set.addon)
    if addon then
      self:ProcessSet(set, addon)
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
  --process everything
  self:ProcessSets()
end

-------------------------------------------------------------------------------
--set up addon
-------------------------------------------------------------------------------
local errorPixie
local EasyPlatEntryInst = EasyPlatEntry:new()
EasyPlatEntryInst:Init()
