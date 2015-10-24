require "Window"

local EasyPlatEntry = {}

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
  if self.xmlDoc == nil then return end
  if not self.xmlDoc:IsLoaded() then return end
end

local EasyPlatEntryInst = EasyPlatEntry:new()
EasyPlatEntryInst:Init()
