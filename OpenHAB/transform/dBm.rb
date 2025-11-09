# Convert dBm to a rough percentage.
if (input.nil? || input == 'NULL')
  'NULL'
else
  dbm = input.to_i

  # Calculate a rough percent based on signal dBm.
  dbm_min = -100.0
  dbm_max =  -35.0
  percent =  100.0 * (1.0 - (dbm_max - dbm) / (dbm_max - dbm_min))
  
  [ [ percent.to_i, 100 ].min, 0].max
end
