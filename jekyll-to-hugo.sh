#!/bin/sh

# Initialize variables
export ROOT="/Users/vigilante"
export HUGOROOT="$ROOT/hugo"
export HUGODOCS="$HUGOROOT/crdbhugodocs"
export JEKYLLDOCS="$ROOT/go/src/github.com/cockroachdb/docs"

# Remove old HUGODOCS

echo "Removing old HUGODOCS folder contents..."

rm -rf $HUGODOCS/content/
rm -rf $HUGODOCS/layouts/partials/
rm $HUGODOCS/config.yml

echo "Done"

# Copy configuration data from $JEKYLLDOCS to $HUGODOCS

echo "Copying configuration..."

cp $JEKYLLDOCS/_config_base.yml $HUGODOCS/config.yml
echo theme: ananke >> config.yml

echo "Done"

# Copy all content from $JEKYLLDOCS to $HUGODOCS

echo "Copying content..."

cp -R $JEKYLLDOCS/_includes/ $HUGODOCS/assets
cp -R $JEKYLLDOCS/_layouts/ $HUGODOCS/layouts
cp -R $JEKYLLDOCS/v1.0 $HUGODOCS/content
cp -R $JEKYLLDOCS/v1.1 $HUGODOCS/content
cp -R $JEKYLLDOCS/v19.1 $HUGODOCS/content
cp -R $JEKYLLDOCS/v19.2 $HUGODOCS/content
cp -R $JEKYLLDOCS/v2.0 $HUGODOCS/content
cp -R $JEKYLLDOCS/v2.1 $HUGODOCS/content
cp -R $JEKYLLDOCS/v20.1 $HUGODOCS/content
cp -R $JEKYLLDOCS/v20.2 $HUGODOCS/content
cp -R $JEKYLLDOCS/v21.1 $HUGODOCS/content
cp -R $JEKYLLDOCS/v21.2 $HUGODOCS/content
cp -R $JEKYLLDOCS/cockroachcloud $HUGODOCS/content
cp -R $JEKYLLDOCS/releases $HUGODOCS/content
cp -R $JEKYLLDOCS/api $HUGODOCS/content
cp -R $JEKYLLDOCS/tutorials $HUGODOCS/content

echo "Done"

# Hugoify the existing Jekyll docs

echo "Hugoifying content"

arr=($HUGODOCS/content $HUGODOCS/layouts)

for x in "${arr[@]}";
do
find $x -type f \( -name "*.md" -o -name "*.html" \) -exec sed -i '' -E 's/(\{\{)([^\s])/\1 \2/g; s/(\{%)([^\s])/\1 \2/g; s/([^\s])(\}\})/\1 \2/g; s/([^\s])(%\})/\1 \2/g; s/(\{\{ ) /\1/g; s/(\{% ) /\1/g; s/ ( \}\})/\1/g; s/ ( %\})/\1/g; s/\{\{ content \}\}/\{\{ .Content \}\}/g; s/\{% include (.*) %\}/\{\{ partial "\1" . \}\}/g' {} \;

done

echo "Done"
