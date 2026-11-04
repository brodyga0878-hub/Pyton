#!/usr/bin/env python3
"""Extract the original 57 vessel descriptors and 19 weighted selection pools.
Data only: no geometry interpreter, ship unlocks or simulation parameters are invented.
"""
import argparse, hashlib, json, struct
from pathlib import Path
from extract_galaxy import EXPECTED

DESCRIPTORS = 0xBA8FC
NAMES = 0xBB044
POOLS = 0xC8280
# Display translations; the English name and its exact bytes remain in every record.
RUSSIAN = [
 'Межпланетный челнок','Истребитель «Стоумастер»','Неизвестный','Грузовой подъёмник',
 'Штурмовик «Скопа»','Штурмовик «Сокол»','Атмосферный истребитель «Ястреб»','Атмосферный истребитель «Пустельга»',
 'Дальний истребитель «Орёл»','Истребитель «Орёл» Mk II','Истребитель «Орёл» Mk III','Сайдвиндер','Штурмовик «Крайт»','Геккон','Гадюка','Перехватчик «Гюрза»','Истребитель «Балобан» III','Штурмовик «Скопа» X','Штурмовик «Дербник»','Перехватчик «Гюрза» Mk II','Истребитель «Кречет»','Кобра Mk I','Мурена','Кобра Mk III','Удав','Исследователь «Аспид»','Ланнер','Истребитель «Харрис»','Штурмовик «Спар»','Исследователь «Виверна»','Крейсер «Скит»','Класс «Тёрнер»','Ланнер II','Лунь',
 'Неизвестный','Неизвестный','Неизвестный','Неизвестный','Транспорт','Транспорт «Лев»','Торговец «Тигр»','Имперский курьер','Грузовик «Питон»','Имперский торговец','Грузовик «Анаконда»','Клипер «Пума»','Грузовик «Боа»','Клипер «Пантера»','Неизвестный','Грузовик «Тирсел»','Имперский исследователь','Командный корабль INRA','Транспорт «Богомол»','Авианосец «Грифон»','Транспорт таргоидов','Тяжёлый грузовик «Рысь»','Дальний крейсер']
POOL_NAMES = ['Группа 00','Торговые суда','Группа 02','Имперские военные','Федеральные военные','Федеральная верфь','Группа 06','Группа 07','Таргоиды','Таргоиды и транспорт','Одиночные пираты','Группы пиратов','Охотники за головами (предположительно)','Челноки и подъёмники','Полиция','Крупные гражданские суда','Цели заказных убийств','Таргоиды и транспорт (17)','Таргоидский корабль (18)']

class Image:
 def __init__(self, data):
  if hashlib.sha256(data).hexdigest() != EXPECTED:
   raise ValueError('Unsupported FIRSTENC.EXE revision')
  self.data = data
  pe = struct.unpack_from('<I',data,60)[0]
  self.base = struct.unpack_from('<I',data,pe+52)[0]
  count = struct.unpack_from('<H',data,pe+6)[0]
  start = pe+24+struct.unpack_from('<H',data,pe+20)[0]
  self.sections = [struct.unpack_from('<4I',data,start+i*40+8) for i in range(count)]
 def offset(self, address, length):
  for _, va, size, raw in self.sections:
   delta = address-self.base-va
   if 0 <= delta and delta+length <= size and raw+delta+length <= len(self.data):
    return raw+delta
  raise ValueError('Pointer outside raw PE section')
 def pointer(self, at, length):
  return self.offset(struct.unpack_from('<I',self.data,at)[0],length)
 def text(self, code):
  if code >> 8 != 0x40 or (code & 255) > 70:
   raise ValueError('Unexpected ship string code')
  at = self.pointer(NAMES+(code & 255)*4,1)
  end = self.data.find(b'\0',at,at+256)
  if end < 0: raise ValueError('Unterminated name')
  return at, self.data[at:end].decode('ascii')

def extract(path):
 b = Path(path).read_bytes(); image = Image(b); ships=[]
 assert len(RUSSIAN) == 57
 for index in range(15,72):
  descriptor = image.pointer(DESCRIPTORS+index*4,68)
  spec = image.pointer(descriptor+56,24)
  raw = b[spec:spec+24]; w = struct.unpack('<12H',raw)
  text_at,name = image.text(w[7])
  ships.append({'index':index,'name_en':name,'name_ru':RUSSIAN[index-15],
   'prototype_id':{15:'shuttle',23:'eagle',38:'cobra'}.get(index,''),
   'descriptor_offset':hex(descriptor),'spec_offset':hex(spec),'name_offset':hex(text_at),
   'spec_hex':raw.hex(),'spec_sha256':hashlib.sha256(raw).hexdigest(),
   'mass_tonnes':w[3],'internal_capacity_tonnes':w[4],'crew':w[8],'missile_slots':w[9],
   'forward_thrust_raw':w[0],'reverse_thrust_raw_signed':struct.unpack_from('<h',raw,2)[0],
   'gun_mounts_raw':w[2],'price_raw':w[5],'name_code':w[7],'drive_raw':w[10],
   'unknown_name':name=='Unknown'})
 pools=[]
 for index in range(19):
  count,address = struct.unpack_from('<II',b,POOLS+index*8)
  if not 1<=count<=64: raise ValueError('Invalid pool length')
  start=image.offset(address,count*4)
  entries=list(struct.unpack_from('<'+'I'*count,b,start))
  if not all(15<=v<72 for v in entries):raise ValueError('Invalid vessel index')
  pools.append({'index':index,'name_ru':POOL_NAMES[index],'offset':hex(start),'entries':entries,
   'bytes_sha256':hashlib.sha256(b[start:start+count*4]).hexdigest()})
 return {'schema':1,'source_sha256':EXPECTED,'descriptor_table_offset':hex(DESCRIPTORS),
  'name_table_offset':hex(NAMES),'pool_table_offset':hex(POOLS),
  'scope':'All descriptors 15..71. Original names and raw specification fields. Weighted pools preserve duplicates; they do not imply spawn counts or original NPC behaviour. Russian names are display translations. No new playable ships.',
  'ships':ships,'selection_pools':pools}

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('executable',type=Path);p.add_argument('output',type=Path)
 a=p.parse_args();data=extract(a.executable)
 a.output.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
 print(f"Extracted {len(data['ships'])} vessel descriptors and {len(data['selection_pools'])} weighted pools")
if __name__=='__main__':main()
