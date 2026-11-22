exclude(:test_disable_autocompact, 'requires the moving compactor auto_compact switch')
exclude(:test_enable_autocompact, 'requires the moving compactor auto_compact switch')
exclude(:test_implicit_compaction_does_something, 'requires automatic moving compaction and considered/moved statistics')
exclude(:test_major_compacts, 'requires automatic moving compaction during a major GC')
