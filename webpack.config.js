module.exports = {
  entry: "./src/aidbox.coffee",
  output: {
    path: process.env.BUILD_DIR || 'dist',
    filename: "angular-aidbox.js"
  },
  module: {
    loaders: [
      { test: /\.coffee$/, loader: "coffee-loader" }
    ]
  },
  resolve: { extensions: ["", ".webpack.js", ".web.js", ".js", ".coffee"]}
};
