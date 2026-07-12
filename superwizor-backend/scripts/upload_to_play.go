package main

import (
	"context"
	"flag"
	"fmt"
	"log"
	"os"
	"strings"

	"golang.org/x/oauth2"
	"google.golang.org/api/androidpublisher/v3"
	"google.golang.org/api/googleapi"
	"google.golang.org/api/option"
)

func main() {
	packageName := flag.String("package", "ai.superwizor.superwizor", "Android App Package Name")
	aabPath := flag.String("aab", "../flutter-app/superwizor/build/app/outputs/bundle/release/app-release.aab", "Path to App Bundle (.aab)")
	keyPath := flag.String("key", "../play-sa-key.json", "Path to Google Play Service Account JSON key")
	trackName := flag.String("track", "internal", "Publish track (internal, alpha, beta, production)")
	accessToken := flag.String("token", "", "Google Play API OAuth Access Token")
	flag.Parse()

	ctx := context.Background()

	// 1. Check files
	if _, err := os.Stat(*aabPath); os.IsNotExist(err) {
		log.Fatalf("❌ Android App Bundle not found at %s. Please run 'flutter build appbundle' first.", *aabPath)
	}

	var opts []option.ClientOption
	if *accessToken != "" {
		fmt.Println("🔑 Authenticating using provided OAuth Access Token...")
		opts = append(opts, option.WithTokenSource(oauth2.StaticTokenSource(&oauth2.Token{
			AccessToken: *accessToken,
		})))
	} else if _, err := os.Stat(*keyPath); err == nil {
		fmt.Printf("🔑 Authenticating using service account key file: %s\n", *keyPath)
		opts = append(opts, option.WithCredentialsFile(*keyPath))
	} else {
		fmt.Println("🔑 Authenticating using local Application Default Credentials (ADC)...")
	}

	service, err := androidpublisher.NewService(ctx, opts...)
	if err != nil {
		log.Fatalf("❌ Failed to create Android Publisher Service: %v", err)
	}

	// 2. Start a new edit transaction
	fmt.Printf("📦 Starting edit transaction for app: %s\n", *packageName)
	editCall := service.Edits.Insert(*packageName, &androidpublisher.AppEdit{})
	edit, err := editCall.Do()
	if err != nil {
		log.Fatalf("❌ Failed to start edit: %v. Make sure the package name is correct and the credentials have access to this app.", err)
	}
	fmt.Printf("   ✅ Edit transaction created (ID: %s)\n", edit.Id)

	// 3. Upload the AAB file
	fmt.Printf("📤 Uploading App Bundle: %s...\n", *aabPath)
	aabFile, err := os.Open(*aabPath)
	if err != nil {
		log.Fatalf("❌ Failed to open AAB file: %v", err)
	}
	defer aabFile.Close()

	// Get file size for log
	fileInfo, _ := aabFile.Stat()
	fmt.Printf("   File size: %.2f MB\n", float64(fileInfo.Size())/(1024*1024))

	uploadCall := service.Edits.Bundles.Upload(*packageName, edit.Id).Media(aabFile, googleapi.ContentType("application/octet-stream"))
	bundle, err := uploadCall.Do()
	if err != nil {
		// Clean up the edit transaction in case of error
		_ = service.Edits.Delete(*packageName, edit.Id).Do()
		log.Fatalf("❌ Failed to upload bundle: %v", err)
	}
	fmt.Printf("   ✅ Bundle uploaded successfully! (Version Code: %d)\n", bundle.VersionCode)

	// 4. Assign the bundle to the specified track
	fmt.Printf("🚀 Deploying bundle to track: %s...\n", *trackName)
	trackRelease := &androidpublisher.TrackRelease{
		VersionCodes: []int64{bundle.VersionCode},
		Status:       "completed",
		Name:         fmt.Sprintf("Release %d", bundle.VersionCode),
	}

	// Add release notes if available (optional)
	releaseNotes, err := loadReleaseNotes()
	if err == nil && len(releaseNotes) > 0 {
		trackRelease.ReleaseNotes = []*androidpublisher.LocalizedText{
			{
				Language: "pl",
				Text:     releaseNotes,
			},
			{
				Language: "en-US",
				Text:     releaseNotes,
			},
		}
		fmt.Println("   📝 Added localized release notes")
	}

	trackUpdateCall := service.Edits.Tracks.Update(*packageName, edit.Id, *trackName, &androidpublisher.Track{
		Track:    *trackName,
		Releases: []*androidpublisher.TrackRelease{trackRelease},
	})
	_, err = trackUpdateCall.Do()
	if err != nil {
		_ = service.Edits.Delete(*packageName, edit.Id).Do()
		log.Fatalf("❌ Failed to assign bundle to track %s: %v", *trackName, err)
	}
	fmt.Printf("   ✅ Assigned to track: %s\n", *trackName)

	// 5. Commit the edit transaction
	fmt.Println("💾 Committing transaction changes to Google Play Console...")
	commitCall := service.Edits.Commit(*packageName, edit.Id)
	committedEdit, err := commitCall.Do()
	if err != nil {
		_ = service.Edits.Delete(*packageName, edit.Id).Do()
		log.Fatalf("❌ Failed to commit edit changes: %v", err)
	}

	fmt.Println("================================================================================")
	fmt.Printf("🎉 SUCCESS! App version %d has been successfully published to the '%s' track!\n", bundle.VersionCode, *trackName)
	fmt.Printf("   Play Console Edit ID: %s\n", committedEdit.Id)
	fmt.Println("================================================================================")
}

func loadReleaseNotes() (string, error) {
	// Look for release notes file in the project
	paths := []string{"release_notes.txt", "../release_notes.txt", "scripts/release_notes.txt"}
	for _, p := range paths {
		if _, err := os.Stat(p); err == nil {
			bytes, err := os.ReadFile(p)
			if err == nil {
				return strings.TrimSpace(string(bytes)), nil
			}
		}
	}

	// Default fallback release notes
	return "Poprawki stabilności i optymalizacja działania.", nil
}
