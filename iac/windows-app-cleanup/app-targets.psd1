# Windows App Cleanup Configuration
# List of common unwanted Windows applications to target for removal

@{
    # Common bloatware applications that can be safely removed
    DefaultTargets = @(
        # Microsoft apps that are often unwanted
        'Microsoft.BingWeather',
        'Microsoft.GetHelp',
        'Microsoft.Getstarted',
        'Microsoft.Microsoft3DViewer',
        'Microsoft.MicrosoftOfficeHub',
        'Microsoft.MicrosoftSolitaireCollection',
        'Microsoft.MixedReality.Portal',
        'Microsoft.Office.OneNote',
        'Microsoft.People',
        'Microsoft.Print3D',
        'Microsoft.SkypeApp',
        'Microsoft.Wallet',
        'Microsoft.WindowsAlarms',
        'Microsoft.WindowsCamera',
        'Microsoft.WindowsFeedbackHub',
        'Microsoft.WindowsMaps',
        'Microsoft.WindowsSoundRecorder',
        'Microsoft.Xbox.TCUI',
        'Microsoft.XboxApp',
        'Microsoft.XboxGameOverlay',
        'Microsoft.XboxGamingOverlay',
        'Microsoft.XboxIdentityProvider',
        'Microsoft.XboxSpeechToTextOverlay',
        'Microsoft.YourPhone',
        'Microsoft.ZuneMusic',
        'Microsoft.ZuneVideo'
        
        # Third-party bloatware commonly found on OEM systems
        'king.com.CandyCrushSaga',
        'king.com.CandyCrushSodaSaga',
        'SpotifyAB.SpotifyMusic',
        'Disney.37853FC22B2CE',
        'AdobeSystemsIncorporated.AdobePhotoshopExpress',
        'ActiproSoftwareLLC.562882FEEB491',
        'Amazon.com.Amazon',
        'Flipboard.Flipboard',
        'ShazamEntertainmentLtd.Shazam',
        'SlingTVLLC.SlingTV',
        'Drawboard.DrawboardPDF',
        'Twitter.Twitter',
        'TheNewYorkTimes.NYTCrossword',
        'Duolingo-LearnLanguagesforFree.PackagedByInstallAware',
        'PandoraMediaInc.29680B314EFC2'
    )

    # Applications to be extra careful with (require explicit confirmation)
    CriticalApps = @(
        'Microsoft.WindowsStore',
        'Microsoft.MSPaint',
        'Microsoft.WindowsCalculator',
        'Microsoft.Windows.Photos',
        'Microsoft.WindowsNotepad',
        'Microsoft.MicrosoftEdge',
        'Microsoft.WebMediaExtensions',
        'Microsoft.VCLibs.140.00',
        'Microsoft.NET.Native.Framework.2.2',
        'Microsoft.NET.Native.Runtime.2.2'
    )

    # Safe test targets for canary runs
    CanaryTargets = @(
        'Microsoft.BingWeather',
        'Microsoft.Getstarted',
        'Microsoft.MicrosoftSolitaireCollection'
    )
}
