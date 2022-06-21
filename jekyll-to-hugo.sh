#!/bin/sh

# Initialize variables
export ROOT="/Users/vigilante"
export HUGOROOT="$ROOT/hugo"
export HUGODOCS="$HUGOROOT/crdbhugodocs"
export JEKYLLDOCS="$ROOT/go/src/github.com/cockroachdb/docs"

# Remove old HUGODOCS

echo "Removing old HUGODOCS folder contents..."

rm -rf $HUGODOCS/content/
rm $HUGODOCS/config.yml

echo "Done"

# Copy configuration data from $JEKYLLDOCS to $HUGODOCS

echo "Copying configuration..."

cp $JEKYLLDOCS/_config_base.yml $HUGODOCS/config.yml
echo theme: ananke >> config.yml
echo uglyurls: true >> config.yml

echo "Done"

# Copy all content from $JEKYLLDOCS to $HUGODOCS

echo "Copying content..."
cp -R $JEKYLLDOCS/api $HUGODOCS/content
mkdir $HUGODOCS/content/api
mv $HUGODOCS/content/* $HUGODOCS/content/api
cp -R $JEKYLLDOCS/v1.0 $HUGODOCS/content
cp -R $JEKYLLDOCS/v2.0 $HUGODOCS/content
cp -R $JEKYLLDOCS/v2.1 $HUGODOCS/content
cp -R $JEKYLLDOCS/v20.1 $HUGODOCS/content
cp -R $JEKYLLDOCS/v20.2 $HUGODOCS/content
cp -R $JEKYLLDOCS/v21.1 $HUGODOCS/content
cp -R $JEKYLLDOCS/v21.2 $HUGODOCS/content
cp -R $JEKYLLDOCS/v22.1 $HUGODOCS/content
cp -R $JEKYLLDOCS/cockroachcloud $HUGODOCS/content
cp -R $JEKYLLDOCS/releases $HUGODOCS/content
cp -R $JEKYLLDOCS/tutorials $HUGODOCS/content
cp -R $JEKYLLDOCS/_includes/ $HUGODOCS/assets
cp -R $JEKYLLDOCS/index.md $HUGODOCS/content/_index.md

# cp -R $JEKYLLDOCS/_layouts/ $HUGODOCS/layouts

echo "Done"

# Hugoify the existing Jekyll docs

echo "Hugoifying content"

arr=($HUGODOCS/content $HUGODOCS/assets)

for x in "${arr[@]}";
do
find $x -type f \( -name "*.md" -o -name "*.html" \) -exec sed -i '' -E 's/(\{\{)\s{0,}(\w)/\1 \2/g;
 s/(\{%)\s{0,}(\w)/\1 \2/g;
  s/(\w)\s{0,}(\}\})/\1 \2/g;
  s/(\w)\s{0,}(%\})/\1 \2/g;
  s/\{\{ content \}\}/\{\{ .Content \}\}/g;
  s/(tags:) (.*)$/\1 \[\2\]/g;
  s/\{% remote_include https:\/\/raw.githubusercontent.com\/cockroachdb\/generated-diagrams\/release-.*\/grammar_svg\/(.*) %\}/\{\{< sql-diagram "\1" >\}\}/g;
  s/\{\{\s{0,1}page.version.version\s{0,1}\}\}/\{\{< page-version >\}\}/g' {}  \;
done

find $HUGODOCS/content -type f -name "index.md" -execdir mv index.md _index.md \;

echo "Done"

hugo server
