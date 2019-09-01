# Be sure to restart your server when you modify this file.

# Version of your assets, change this if you want to expire all your assets.
Rails.application.config.assets.version = '1.0'

# Add additional assets to the asset load path.
# Rails.application.config.assets.paths << Emoji.images_path
# Add Yarn node_modules folder to the asset load path.
Rails.application.config.assets.paths << Rails.root.join('node_modules')
# Rails.application.config.assets.paths << Rails.root.join('vendor/assets/javascripts')

# Precompile additional assets.
# application.js, application.css, and all non-JS/CSS in the app/assets
# folder are already added.
# Rails.application.config.assets.precompile += %w( admin.js admin.css )
Rails.application.config.assets.precompile += %w( sensing.js sensing.css )
Rails.application.config.assets.precompile += %w( participants.js participants.css )
Rails.application.config.assets.precompile += %w( study.js study.css )
Rails.application.config.assets.precompile += %w( material.js material.css )
Rails.application.config.assets.precompile += %w( notebook.js notebook.css )
Rails.application.config.assets.precompile += %w( captures.css )
Rails.application.config.assets.precompile += %w( user.css )
Rails.application.config.assets.precompile += %w( captures.js )
Rails.application.config.assets.precompile += %w( user.js )
